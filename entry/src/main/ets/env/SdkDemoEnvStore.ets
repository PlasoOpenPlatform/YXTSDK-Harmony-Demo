import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { SdkDemoEnvProfile } from './SdkDemoEnvProfile';

/**
 * 持久化当前环境，以及用户填写的 appId / signKey。代码中不内置密钥。
 */
export class SdkDemoEnvStore {
  static readonly MISSING_CREDENTIALS: string = 'missing_appId_or_signKey';

  private static readonly PREF_STORE: string = 'sdk_demo_prefs';
  private static readonly PREF_ENV_KEY: string = 'server_env';

  private static cachedEnv: string = SdkDemoEnvProfile.DEFAULT_ENV;
  private static appIdMap: Map<string, string> = new Map();
  private static signKeyMap: Map<string, string> = new Map();

  static getEnv(): string {
    return SdkDemoEnvStore.cachedEnv;
  }

  static getAppId(envType?: string): string {
    const env: string = envType !== undefined ? envType : SdkDemoEnvStore.cachedEnv;
    const value: string | undefined = SdkDemoEnvStore.appIdMap.get(env);
    if (value === undefined) {
      return '';
    }
    return value.trim();
  }

  static getSignKey(envType?: string): string {
    const env: string = envType !== undefined ? envType : SdkDemoEnvStore.cachedEnv;
    const value: string | undefined = SdkDemoEnvStore.signKeyMap.get(env);
    if (value === undefined) {
      return '';
    }
    return value.trim();
  }

  static hasCredentials(envType?: string): boolean {
    return SdkDemoEnvStore.getAppId(envType).length > 0 && SdkDemoEnvStore.getSignKey(envType).length > 0;
  }

  static setCredentials(envType: string, appId: string, signKey: string): void {
    const env: string = SdkDemoEnvProfile.normalizeEnv(envType);
    const trimmedAppId: string = appId.trim();
    const trimmedSignKey: string = signKey.trim();
    if (trimmedAppId.length > 0) {
      SdkDemoEnvStore.appIdMap.set(env, trimmedAppId);
    } else {
      SdkDemoEnvStore.appIdMap.delete(env);
    }
    if (trimmedSignKey.length > 0) {
      SdkDemoEnvStore.signKeyMap.set(env, trimmedSignKey);
    } else {
      SdkDemoEnvStore.signKeyMap.delete(env);
    }
  }

  static async load(context: common.Context): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, SdkDemoEnvStore.PREF_STORE);
      const saved = await store.get(SdkDemoEnvStore.PREF_ENV_KEY, SdkDemoEnvProfile.DEFAULT_ENV);
      const env: string = typeof saved === 'string' ? saved : SdkDemoEnvProfile.DEFAULT_ENV;
      SdkDemoEnvStore.cachedEnv = SdkDemoEnvProfile.normalizeEnv(env);
      const envList: string[] = SdkDemoEnvProfile.getEnvList();
      for (let i = 0; i < envList.length; i++) {
        await SdkDemoEnvStore.loadCredential(store, envList[i]);
      }
    } catch (_e) {
      SdkDemoEnvStore.cachedEnv = SdkDemoEnvProfile.DEFAULT_ENV;
    }
    return SdkDemoEnvStore.cachedEnv;
  }

  static async save(context: common.Context, envType: string): Promise<void> {
    const env: string = SdkDemoEnvProfile.normalizeEnv(envType);
    SdkDemoEnvStore.cachedEnv = env;
    try {
      const store = await preferences.getPreferences(context, SdkDemoEnvStore.PREF_STORE);
      await store.put(SdkDemoEnvStore.PREF_ENV_KEY, env);
      const envList: string[] = SdkDemoEnvProfile.getEnvList();
      for (let i = 0; i < envList.length; i++) {
        await SdkDemoEnvStore.saveCredential(store, envList[i]);
      }
      await store.flush();
    } catch (_e) {
      // 内存缓存仍可用
    }
  }

  private static prefSuffix(envType: string): string {
    return envType.replace('!', '');
  }

  private static async loadCredential(store: preferences.Preferences, envType: string): Promise<void> {
    const suffix: string = SdkDemoEnvStore.prefSuffix(envType);
    const savedAppId = await store.get(`appId_${suffix}`, '');
    const savedSignKey = await store.get(`signKey_${suffix}`, '');
    if (typeof savedAppId === 'string' && savedAppId.trim().length > 0) {
      SdkDemoEnvStore.appIdMap.set(envType, savedAppId.trim());
    } else {
      SdkDemoEnvStore.appIdMap.delete(envType);
    }
    if (typeof savedSignKey === 'string' && savedSignKey.trim().length > 0) {
      SdkDemoEnvStore.signKeyMap.set(envType, savedSignKey.trim());
    } else {
      SdkDemoEnvStore.signKeyMap.delete(envType);
    }
  }

  private static async saveCredential(store: preferences.Preferences, envType: string): Promise<void> {
    const suffix: string = SdkDemoEnvStore.prefSuffix(envType);
    await store.put(`appId_${suffix}`, SdkDemoEnvStore.getAppId(envType));
    await store.put(`signKey_${suffix}`, SdkDemoEnvStore.getSignKey(envType));
  }
}
