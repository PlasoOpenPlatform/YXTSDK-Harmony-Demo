import { buffer } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * getToken 请求参数 HmacSHA1 签名（Demo 专用，不进入 yxtsdk）。
 */
export class SdkDemoSignHelper {
  static sign(params: Map<string, string | number>, signKey: string): void {
    const keys: string[] = Array.from(params.keys()).sort();
    let sortedParams: string = '';
    for (let index = 0; index < keys.length; index++) {
      const key: string = keys[index];
      if (index > 0) {
        sortedParams += '&';
      }
      sortedParams += `${key}=${params.get(key)}`;
    }
    params.set('signature', SdkDemoSignHelper.encrypt(sortedParams, signKey));
  }

  private static encrypt(plainText: string, signKey: string): string {
    const signKeyBytes: Uint8Array = new Uint8Array(buffer.from(signKey, 'utf-8').buffer);
    const contentBytes: Uint8Array = new Uint8Array(buffer.from(plainText, 'utf-8').buffer);
    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
    const symKey = symKeyGenerator.convertKeySync({ data: signKeyBytes });
    const mac = cryptoFramework.createMac('SHA1');
    mac.initSync(symKey);
    mac.updateSync({ data: contentBytes });
    const macOutput = mac.doFinalSync();
    return SdkDemoSignHelper.bytesToUpperHex(macOutput.data);
  }

  private static bytesToUpperHex(data: Uint8Array): string {
    let hexString: string = '';
    for (let i = 0; i < data.length; i++) {
      hexString += ('00' + data[i].toString(16)).slice(-2);
    }
    return hexString.toUpperCase();
  }
}
