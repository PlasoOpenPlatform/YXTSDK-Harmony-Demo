# 云学堂 SDK（yxtsdk）接入说明

第三方 App 只需依赖一个 OHPM 包 `yxtsdk`，完成初始化、写入 Token，即可打开实时课堂（含历史课堂入口）。

| 项 | 说明 |
|----|------|
| OHPM 包名 | `yxtsdk` |
| 当前版本 | `1.0.27` |
| API 入口 | `YxtSDK` |
| 本仓库 | 最小可运行 Demo（`com.plaso.sdkdemo`） |

---

## 1. 添加依赖

DevEco Studio（HarmonyOS API 12+ / SDK 5.0.0(12)+）。进原生课建议真机。

工程根目录配置 `.ohpmrc`（仅拉取，不要放 publish 密钥）：

```ini
registry=http://nexus.plaso.cn:8088/repos/ohpm,http://nexus.plaso.cn:8088/repos/ohos,https://repo.harmonyos.com/ohpm/
@ohos:registry=http://nexus.plaso.cn:8088/repos/ohos,https://repo.harmonyos.com/ohpm/
@yxt:registry=http://nexus.plaso.cn:8088/repos/yxt
strict_ssl=false
```

在 `entry/oh-package.json5`：

```json5
{
  "dependencies": {
    "yxtsdk": "1.0.27"
  }
}
```

然后 Sync Project / `ohpm install`。

---

## 2. Ability 生命周期（必接）

课堂模块依赖 Ability / WindowStage。请在宿主 `UIAbility` 中统一转发到 `YxtSDK`：

```typescript
import { common } from '@kit.AbilityKit';
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { YxtSDK } from 'yxtsdk';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    YxtSDK.onAbilityCreate(this);
    // 第二参数为公司开通的机构标识（appId / orgName）
    YxtSDK.init(this.context, 'yourAppId', {
      onInitSuccess: () => {},
      onInitError: (code: number) => {}
    });
    YxtSDK.setServerEnv('p!');
  }

  onDestroy(): void {
    YxtSDK.onAbilityDestroy(this);
    YxtSDK.release(this.context as common.Context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 进课横屏、全屏、隐藏系统栏依赖此步骤
    YxtSDK.onWindowStageCreate(this, windowStage);
    windowStage.loadContent('pages/Index', () => {});
  }

  onWindowStageDestroy(): void {
    YxtSDK.onWindowStageDestroy(this);
  }
}
```

`init` 会按 HAR 默认环境覆盖一次，因此 `setServerEnv` 请放在 `init` 之后。

---

## 3. 权限

在 `module.json5` 中声明申请：

- `ohos.permission.INTERNET`
- `ohos.permission.CAMERA`
- `ohos.permission.MICROPHONE`

进课前按系统要求动态申请相机 / 麦克风。

---

## 4. Token 与打开实时课堂

Token 由**后方服务端**获取，客户端不要把密钥写进 App。调用顺序：`init` 成功 → `updateToken` 成功 → 打开课堂。

```typescript
import { YxtSDK, YxtSdkGetLiveClassHomePage, YxtSdkLiveClassOptions } from 'yxtsdk';

YxtSDK.updateToken(token, {
  onInitSuccess: () => {
    // Token 就绪，可以进课
  },
  onInitError: (code: number) => {},
  onTokenError: () => {
    // Token 失效：重新取 Token 再调 updateToken
  }
});
```

### 4.1 全屏打开课堂

打开合并页（实时课堂 + 历史课堂）：

```typescript
const options: YxtSdkLiveClassOptions = new YxtSdkLiveClassOptions();
YxtSDK.startLiveClass(abilityContext, options);
```

退出登录：`YxtSDK.doLogout()`。

### 4.2 嵌入页面打开课堂

在自有页面中嵌入合并页（需放在 `@Builder` 中）：

```typescript
import { YxtSdkGetLiveClassHomePage, YxtSdkLiveClassOptions } from 'yxtsdk';

private readonly options: YxtSdkLiveClassOptions = (() => {
  const value: YxtSdkLiveClassOptions = new YxtSdkLiveClassOptions();
  return value;
})();

@Builder
private liveClassBuilder(): void {
  YxtSdkGetLiveClassHomePage(this.options);
}

build() {
  Column() {
    this.liveClassBuilder();
  }
  .width('100%')
  .layoutWeight(1)
  .clip(true);
}
```

`YxtSdkLiveClassOptions`：

| 字段 | 说明 |
|------|------|
| `initialTab` | 初始 Tab，默认实时课堂 |

### 4.3 常见错误码

| 码 | 含义 |
|----|------|
| 10001 | 初始化失败 |
| 10002 | Token 为空 |
| 10003 | 机构标识无效 |
| 10004 | 未初始化 |
| 10005 | updateToken 失败 |

---

## 5. 进课横竖说明

进入原生实时课后，SDK 会：

- 手机强制横屏
- 隐藏全屏导航状态栏 / 导航栏

前提是已调用 `YxtSDK.onWindowStageCreate`。漏接可能导致竖屏、白底、状态栏仍可见。

---

## 6. 本地 H5 壳页 `new_zy.html`

### 6.1 作用

`new_zy.html` 是课堂相关 **本地 H5 壳页**，由 WebView 加载后，再按环境参数拉取远端 `js/all.js` 等资源。用于：

- 历史课堂 / 回放
- 极速直播等 Web 课堂场景
- 教材中心等课内 WebView（如 `file://…/new_zy.html?…`）

壳页本身不承载业务 UI，只负责解析 URL 参数（如 `dhost`、`rhost`、`initjs`）、展示加载态，并动态引入远端脚本。

### 6.2 为何 Demo / 宿主需要单独放置

鸿蒙 **HAR 包内的 `resfile` 不会自动合并进宿主 HAP**。若宿主工程没有自己的 `new_zy.html`，仅依赖 `yxtsdk` / `@yxt/live` HAR，进历史课或相关 Web 页时可能找不到本地壳页。

因此本 Demo 在宿主模块中放了一份：

```text
entry/src/main/resources/resfile/new_zy.html
```

`YxtSDK.init` → 课堂模块初始化时，SDK 还会从 live HAR 的 rawfile **抽出**壳页到应用沙箱 `filesDir/yxt_web`；宿主 **没有** `resfile/new_zy.html` 时，会回落到该目录。建议正式接入仍按 Demo 方式把文件拷进宿主 `resfile`，与 Android 放 `assets` 的习惯一致，减少路径差异。

### 6.3 使用说明（接入方）

1. 从本 Demo 复制 `entry/src/main/resources/resfile/new_zy.html` 到宿主同路径（`模块名/src/main/resources/resfile/new_zy.html`）。
2. **不要改文件名**；业务侧一般无需手动 `loadUrl`，由 SDK 在历史课 / 教材 WebView 等场景自动加载。
3. 正常走 `YxtSDK.init` 即可；无需额外调用。若未拷贝到宿主 `resfile`，依赖 SDK 抽出到 `filesDir/yxt_web` 的回落路径（见上）。
4. 壳页依赖网络加载远端 JS；加载超时约 30 秒会显示「网络故障，刷新试试哦~」，可点刷新重试。
5. 请保持与当前 `yxtsdk` 发行包配套的壳页版本；随意替换或删减可能导致历史课 / 教材页白屏。

---

## 7. 运行本 Demo

1. DevEco 打开本仓库目录  
2. 确认 `entry/oh-package.json5` 中 `"yxtsdk": "1.0.27"`，并配置 `.ohpmrc`  
3. Sync / `ohpm install`  
4. 配置签名（包名 `com.plaso.sdkdemo`）  
5. Run → `entry`  
6. 填写公司 appId / signKey，登录后进入实时课堂  

本仓库 `entry/src/main/ets/auth/` 只是 **Demo 取 Token 工具**，正式接入请换成后方服务端接口；该目录**不会**打进 `yxtsdk` HAR。

---

## 8. 自检清单

- [ ] 已声明 `yxtsdk` `1.0.27` 依赖
- [ ] Ability 四个生命周期均转发到 `YxtSDK`
- [ ] 相机 / 麦克风权限已申请
- [ ] 宿主已放置 `resources/resfile/new_zy.html`（或确认走 SDK `filesDir/yxt_web` 回落）
- [ ] `init` → `updateToken` 成功后再 `startLiveClass` 或嵌入 `YxtSdkGetLiveClassHomePage`
- [ ] 真机进课可横屏全屏、正常开课；历史课堂 / 回放可打开
