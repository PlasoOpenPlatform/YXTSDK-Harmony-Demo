import { http } from '@kit.NetworkKit';
import { SdkDemoConstants } from '../common/SdkDemoConstants';
import { SdkDemoEnvProfile } from '../env/SdkDemoEnvProfile';
import { SdkDemoEnvStore } from '../env/SdkDemoEnvStore';
import { SdkDemoSignHelper } from './SdkDemoSignHelper';

const TAG: string = 'SdkDemoGetTokenService';

interface GetTokenRequestBody {
  loginName: string;
  userType: string;
  appId: string;
  validTime: number;
  validBegin: number;
  signature: string;
}

interface GetTokenObjPayload {
  code?: number;
  token?: string;
  expire?: number;
}

interface GetTokenResponsePayload {
  code?: number;
  msg?: string;
  obj?: GetTokenObjPayload;
}

export class SdkDemoGetTokenResult {
  token: string | null = null;
  errorMsg: string = '';
}

/**
 * Demo 专用：通过用户名换取 Token（不进入 yxtsdk HAR）。
 */
export class SdkDemoGetTokenService {
  static async getTokenByLoginName(loginName: string, envType: string): Promise<SdkDemoGetTokenResult> {
    const result: SdkDemoGetTokenResult = new SdkDemoGetTokenResult();
    const trimmedName: string = loginName.trim();
    if (trimmedName.length === 0) {
      result.errorMsg = 'loginName empty';
      return result;
    }
    if (!SdkDemoEnvStore.hasCredentials(envType)) {
      result.errorMsg = SdkDemoEnvStore.MISSING_CREDENTIALS;
      console.error(`${TAG} skip getToken: appId or signKey is empty`);
      return result;
    }
    const params: Map<string, string | number> = new Map();
    params.set('appId', SdkDemoEnvStore.getAppId(envType));
    params.set('validTime', SdkDemoConstants.TOKEN_VALID_SECONDS);
    params.set('validBegin', Math.floor(Date.now() / 1000));
    params.set('loginName', trimmedName);
    params.set('userType', SdkDemoConstants.GET_TOKEN_USER_TYPE);
    SdkDemoSignHelper.sign(params, SdkDemoEnvStore.getSignKey(envType));

    const body: GetTokenRequestBody = {
      loginName: trimmedName,
      userType: SdkDemoConstants.GET_TOKEN_USER_TYPE,
      appId: params.get('appId') as string,
      validTime: params.get('validTime') as number,
      validBegin: params.get('validBegin') as number,
      signature: params.get('signature') as string
    };

    const url: string = SdkDemoEnvProfile.getGetTokenUrl(envType);
    const requestBody: string = JSON.stringify(body);
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json; charset=utf-8'
        },
        extraData: requestBody,
        connectTimeout: 15000,
        readTimeout: 15000
      });
      const responseText: string =
        typeof response.result === 'string' ? response.result as string : JSON.stringify(response.result);
      if (response.responseCode !== http.ResponseCode.OK) {
        result.errorMsg = `http ${response.responseCode}`;
        console.error(`${TAG} http error ${response.responseCode}`);
        return result;
      }
      const payload: GetTokenResponsePayload = JSON.parse(responseText) as GetTokenResponsePayload;
      const token: string | undefined = payload.obj?.token;
      const topCode: number | undefined = payload.code;
      const nestedCode: number | undefined = payload.obj?.code;
      const businessOk: boolean =
        (token !== undefined && token.length > 0) && (topCode === 0 || nestedCode === 0);
      if (!businessOk) {
        result.errorMsg = payload.msg !== undefined && payload.msg.length > 0 ?
          payload.msg : `code=${topCode}`;
        console.error(`${TAG} business error code=${topCode}`);
        return result;
      }
      result.token = token as string;
      return result;
    } catch (e) {
      result.errorMsg = 'exception';
      console.error(`${TAG} exception ${JSON.stringify(e)}`);
      return result;
    } finally {
      httpRequest.destroy();
    }
  }
}
