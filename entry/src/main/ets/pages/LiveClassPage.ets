import { YxtSdkGetLiveClassHomePage, YxtSdkLiveClassOptions } from 'yxtsdk';

/**
 * 全屏课堂页。
 * 日程页回放导航由 YxtSDK.init 自动安装，无需再调 installSdkHostNavigation()。
 */
@Entry
@Component
struct LiveClassPage {
  private readonly embedOptions: YxtSdkLiveClassOptions = LiveClassPage.createEmbedOptions();

  private static createEmbedOptions(): YxtSdkLiveClassOptions {
    const options: YxtSdkLiveClassOptions = new YxtSdkLiveClassOptions();
    return options;
  }

  @Builder
  private embedHomeBuilder(): void {
    YxtSdkGetLiveClassHomePage(this.embedOptions);
  }

  build() {
    Column() {
      this.embedHomeBuilder();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White);
  }
}
