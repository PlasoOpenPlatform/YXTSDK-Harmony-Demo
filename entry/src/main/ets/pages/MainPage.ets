import { bundleManager } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { YxtSDK, YxtSdkGetLiveClassHomePage, YxtSdkLiveClassOptions } from 'yxtsdk';
import YxtSdkBuildProfile from 'yxtsdk/BuildProfile';
import { SdkDemoConstants } from '../common/SdkDemoConstants';

@Entry
@Component
struct MainPage {
  @State private showEmbed: boolean = false;
  @State private appVersionLabel: string = '';
  @State private yxtSdkVersionLabel: string = '';
  private readonly embedOptions: YxtSdkLiveClassOptions = MainPage.createEmbedOptions();

  aboutToAppear(): void {
    this.loadAppVersion();
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

  private static createEmbedOptions(): YxtSdkLiveClassOptions {
    const options: YxtSdkLiveClassOptions = new YxtSdkLiveClassOptions();
    return options;
  }

  private logout(): void {
    YxtSDK.doLogout();
    router.replaceUrl({ url: 'pages/Index' }, () => {
    });
  }

  @Builder
  private embedHomeBuilder(): void {
    YxtSdkGetLiveClassHomePage(this.embedOptions);
  }

  build() {
    Column() {
      Text($r('app.string.sdk_demo_title'))
        .width('100%')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 24 });

      Button($r('app.string.sdk_demo_btn_live_class'))
        .width('100%')
        .height(56)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LiveClassPage' });
        });

      Row() {
        Text($r('app.string.sdk_demo_embed_toggle'))
          .fontSize(14)
          .fontColor('#333333')
          .layoutWeight(1);
        Toggle({ type: ToggleType.Switch, isOn: this.showEmbed })
          .onChange((isOn: boolean) => {
            this.showEmbed = isOn;
          });
      }
      .width('100%')
      .margin({ top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center);

      if (this.showEmbed) {
        Column() {
          this.embedHomeBuilder();
        }
        .width('100%')
        .layoutWeight(1)
        .clip(true);
      } else {
        Column()
          .layoutWeight(1)
          .width('100%');
      }

      Button($r('app.string.sdk_demo_btn_logout'))
        .width('100%')
        .height(48)
        .backgroundColor('#EEEEEE')
        .fontColor('#333333')
        .onClick(() => {
          this.logout();
        });

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
      .width('100%')
      .margin({ top: 12 });
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
