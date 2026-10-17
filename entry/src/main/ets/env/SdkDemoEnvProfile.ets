/**
 * 对外 Demo 仅使用线上环境。不含 appId / signKey。
 */
export class SdkDemoEnvProfile {
  static readonly ENV_RELEASE: string = 'p!';
  static readonly DEFAULT_ENV: string = 'p!';
  static readonly GET_TOKEN_PATH: string = '/dataentry/user/getToken';

  static getEnvList(): string[] {
    return [SdkDemoEnvProfile.ENV_RELEASE];
  }

  static isSupportedEnv(envType: string): boolean {
    return envType === SdkDemoEnvProfile.ENV_RELEASE;
  }

  static getOemBaseUrl(envType: string): string {
    if (!SdkDemoEnvProfile.isSupportedEnv(envType)) {
      return 'https://www.plaso.cn';
    }
    return 'https://www.plaso.cn';
  }

  static getGetTokenUrl(envType: string): string {
    return `${SdkDemoEnvProfile.getOemBaseUrl(envType)}${SdkDemoEnvProfile.GET_TOKEN_PATH}`;
  }

  static normalizeEnv(envType: string): string {
    return SdkDemoEnvProfile.isSupportedEnv(envType) ? envType : SdkDemoEnvProfile.DEFAULT_ENV;
  }
}
