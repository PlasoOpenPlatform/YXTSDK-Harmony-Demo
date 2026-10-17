import { common } from '@kit.AbilityKit';
import { YxtSDK } from 'yxtsdk';
import { SdkDemoEnvStore } from '../env/SdkDemoEnvStore';

const TAG: string = 'SdkDemoSdkBootstrap';

/**
 * 按当前环境初始化 SDK。init 会使用 HAR 默认环境覆盖一次，因此必须在 init 之后再 setServerEnv。
 * appId / signKey 为空时跳过初始化，由调用方提示用户。
 *
 * 宿主导航：YxtSDK.init → LiveSDK.initLiveClass 已自动安装默认回放导航，
 * 无需再调 YxtSDK.installSdkHostNavigation()（该方法仅作兼容/高级覆盖保留）。
 */
export class SdkDemoSdkBootstrap {
  static applyCurrentEnv(context: common.Context): boolean {
    if (!SdkDemoEnvStore.hasCredentials()) {
      console.error(`${TAG} skip YxtSDK.init: appId or signKey is empty`);
      return false;
    }
    const env: string = SdkDemoEnvStore.getEnv();
    YxtSDK.init(context, SdkDemoEnvStore.getAppId(env));
    YxtSDK.setServerEnv(env);
    return true;
  }
}
