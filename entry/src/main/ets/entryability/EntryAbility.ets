import { ConfigurationConstant, common } from '@kit.AbilityKit';
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { YxtSDK } from 'yxtsdk';
import { SdkDemoEnvStore } from '../env/SdkDemoEnvStore';
import { SdkDemoSdkBootstrap } from '../common/SdkDemoSdkBootstrap';

const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    YxtSDK.onAbilityCreate(this);
    void this.bootstrapSdk();
  }

  private async bootstrapSdk(): Promise<void> {
    await SdkDemoEnvStore.load(this.context);
    if (!SdkDemoSdkBootstrap.applyCurrentEnv(this.context)) {
      console.error(`${TAG} YxtSDK init skipped: fill appId and signKey first`);
      return;
    }
  }

  onDestroy(): void {
    YxtSDK.onAbilityDestroy(this);
    YxtSDK.release(this.context as common.Context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    YxtSDK.onWindowStageCreate(this, windowStage);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error(`${TAG} loadContent failed: ${JSON.stringify(err)}`);
      }
    });
  }

  onWindowStageDestroy(): void {
    YxtSDK.onWindowStageDestroy(this);
  }
}
