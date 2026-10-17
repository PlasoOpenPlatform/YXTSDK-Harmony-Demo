import { bundleManager, common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { YxtSDK } from 'yxtsdk';
import YxtSdkBuildProfile from 'yxtsdk/BuildProfile';
import { SdkDemoGetTokenService } from '../auth/SdkDemoGetTokenService';
import { SdkDemoConstants } from '../common/SdkDemoConstants';
import { SdkDemoSdkBootstrap } from '../common/SdkDemoSdkBootstrap';
import { SdkDemoEnvStore } from '../env/SdkDemoEnvStore';

@Entry
@Component
struct Index {
  @State private usernameInput: string = '';
  @State private loading: boolean = false;
  @State private statusMessage: string = '';
  @State private appVersionLabel: string = '';
  @State private yxtSdkVersionLabel: string = '';

  aboutToAppear(): void {
    this.loadAppVersion();
    this.reloadEnvAndValidate();
  }

  private loadAppVersion(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersionLabel = `v${info.versionName}`;
    } catch (e) {
      console.error(`SdkDemo: failed to read app version: ${JSON.stringify(e)}`);
      this.appVersionLabel = '';
    }
    this.yxtSdkVersionLabel = `yxtsdk v${YxtSdkBuildProfile.HAR_VERSION}`;
  }

  onPageShow(): void {
    this.reloadEnvAndValidate();
  }

  private getAbilityContext(): common.UIAbilityContext | undefined {
    const ctx = getContext(this);
    if (ctx === undefined) {
      return undefined;
    }
    return ctx as common.UIAbilityContext;
  }

  private openEnvSettings(): void {
    router.pushUrl({ url: 'env/EnvSettingsPage' });
  }

  private reloadEnvAndValidate(): void {
    const abilityContext = this.getAbilityContext();
    if (abilityContext === undefined) {
      return;
    }
    void SdkDemoEnvStore.load(abilityContext).then(() => {
      this.applyEnvOrShowCredentialError(abilityContext);
    });
  }

  private missingCredentialMessage(): string {
    return getContext(this).resourceManager.getStringSync($r('app.string.sdk_demo_err_missing_credentials').id);
  }

  private applyEnvOrShowCredentialError(abilityContext: common.UIAbilityContext): void {
    if (!SdkDemoEnvStore.hasCredentials()) {
      this.statusMessage = this.missingCredentialMessage();
      return;
    }
    if (this.statusMessage === this.missingCredentialMessage()) {
      this.statusMessage = '';
    }
    SdkDemoSdkBootstrap.applyCurrentEnv(abilityContext);
  }

  private login(): void {
    if (!SdkDemoEnvStore.hasCredentials()) {
      this.statusMessage = this.missingCredentialMessage();
      return;
    }
    const trimmedUser: string = this.usernameInput.trim();
    if (trimmedUser.length === 0) {
      this.statusMessage = getContext(this).resourceManager.getStringSync($r('app.string.sdk_demo_err_empty_username').id);
      return;
    }
    const abilityContext = this.getAbilityContext();
    if (abilityContext === undefined) {
      return;
    }
    void this.requestTokenAndEnter(abilityContext, trimmedUser);
  }

  private async requestTokenAndEnter(abilityContext: common.UIAbilityContext, trimmedUser: string): Promise<void> {
    this.loading = true;
    this.statusMessage = getContext(this).resourceManager.getStringSync($r('app.string.sdk_demo_status_loading').id);
    if (!SdkDemoSdkBootstrap.applyCurrentEnv(abilityContext)) {
      this.loading = false;
      this.statusMessage = this.missingCredentialMessage();
      return;
    }
    const env: string = SdkDemoEnvStore.getEnv();
    const tokenResult = await SdkDemoGetTokenService.getTokenByLoginName(trimmedUser, env);
    if (tokenResult.token === null) {
      this.loading = false;
      if (tokenResult.errorMsg === SdkDemoEnvStore.MISSING_CREDENTIALS) {
        this.statusMessage = this.missingCredentialMessage();
        return;
      }
      const failedText: string =
        getContext(this).resourceManager.getStringSync($r('app.string.sdk_demo_err_get_token_failed').id);
      this.statusMessage = tokenResult.errorMsg.length > 0 ? `${failedText}：${tokenResult.errorMsg}` : failedText;
      return;
    }
    YxtSDK.updateToken(tokenResult.token, {
      onInitSuccess: () => {
        this.loading = false;
        this.statusMessage = '';
        router.replaceUrl({ url: 'pages/MainPage' }, () => {
        });
      },
      onInitError: () => {
        this.loading = false;
        this.statusMessage =
          getContext(this).resourceManager.getStringSync($r('app.string.sdk_demo_err_update_token_failed').id);
      }
    });
  }

  build() {
    Column() {
      Column({ space: 16 }) {
        Text($r('app.string.sdk_demo_title'))
          .width('100%')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center);

        Button($r('app.string.sdk_demo_btn_env_settings'))
          .width('100%')
          .height(40)
          .backgroundColor('#EEEEEE')
          .fontColor('#333333')
          .onClick(() => {
            this.openEnvSettings();
          });

        Text($r('app.string.sdk_demo_label_username')).fontSize(14).fontColor('#333333');
        TextInput({ text: this.usernameInput, placeholder: $r('app.string.sdk_demo_hint_username') })
          .width('100%')
          .onChange((value: string) => {
            this.usernameInput = value;
          });

        Button($r('app.string.sdk_demo_btn_login'))
          .width('100%')
          .height(48)
          .enabled(!this.loading)
          .onClick(() => {
            this.login();
          });

        if (this.statusMessage.length > 0) {
          Text(this.statusMessage)
            .fontSize(14)
            .fontColor('#C62828');
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      Blank();

      Column({ space: 4 }) {
        if (this.appVersionLabel.length > 0) {
          Text(this.appVersionLabel)
            .width('100%')
            .fontSize(12)
            .fontColor('#999999')
            .textAlign(TextAlign.Center);
        }
        if (this.yxtSdkVersionLabel.length > 0) {
          Text(this.yxtSdkVersionLabel)
            .width('100%')
            .fontSize(12)
            .fontColor('#999999')
            .textAlign(TextAlign.Center);
        }
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .padding({
      left: 24,
      right: 24,
      bottom: 24,
      top: SdkDemoConstants.PAGE_TOP_INSET_VP
    });
  }
}
