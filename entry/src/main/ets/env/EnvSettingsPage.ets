import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { SdkDemoConstants } from '../common/SdkDemoConstants';
import { SdkDemoEnvProfile } from './SdkDemoEnvProfile';
import { SdkDemoEnvStore } from './SdkDemoEnvStore';

@Entry
@Component
struct EnvSettingsPage {
  @State private appIdInput: string = SdkDemoEnvStore.getAppId(SdkDemoEnvProfile.DEFAULT_ENV);
  @State private signKeyInput: string = SdkDemoEnvStore.getSignKey(SdkDemoEnvProfile.DEFAULT_ENV);

  private getAbilityContext(): common.UIAbilityContext | undefined {
    const ctx = getContext(this);
    if (ctx === undefined) {
      return undefined;
    }
    return ctx as common.UIAbilityContext;
  }

  private async applyAndBack(): Promise<void> {
    const abilityContext = this.getAbilityContext();
    if (abilityContext === undefined) {
      return;
    }
    SdkDemoEnvStore.setCredentials(SdkDemoEnvProfile.DEFAULT_ENV, this.appIdInput, this.signKeyInput);
    await SdkDemoEnvStore.save(abilityContext, SdkDemoEnvProfile.DEFAULT_ENV);
    router.back();
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button($r('app.string.sdk_demo_btn_back'))
          .height(36)
          .onClick(() => {
            void this.applyAndBack();
          });
        Text($r('app.string.sdk_demo_env_page_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 });
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text($r('app.string.sdk_demo_env_hint'))
        .fontSize(14)
        .fontColor('#666666');

      Text($r('app.string.sdk_demo_env_app_id'))
        .fontSize(14)
        .margin({ top: 8 });
      TextInput({ text: this.appIdInput, placeholder: $r('app.string.sdk_demo_env_app_id') })
        .width('100%')
        .onChange((value: string) => {
          this.appIdInput = value;
        });

      Text($r('app.string.sdk_demo_env_sign_key'))
        .fontSize(14);
      TextInput({ text: this.signKeyInput, placeholder: $r('app.string.sdk_demo_env_sign_key') })
        .width('100%')
        .onChange((value: string) => {
          this.signKeyInput = value;
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .padding({
      left: 24,
      right: 24,
      bottom: 24,
      top: SdkDemoConstants.PAGE_TOP_INSET_VP
    })
    .alignItems(HorizontalAlign.Start);
  }
}
