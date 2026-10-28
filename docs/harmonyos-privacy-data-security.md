# 鸿蒙应用隐私保护与数据安全

> 适用前提：做权限申请、隐私声明、敏感数据落盘/跨设备同步时的合规与实现速查。
> 核实自官方最佳实践《应用隐私保护》《应用数据安全》原文
> （developer.huawei.com doccenter-architecture，2026-10-28 逐节复核）。
> 权限 API 细节见官方 `request-user-authorization`；密钥全生命周期见 `huks-overview`。

## 一、隐私保护

### 六条原则（产品设计阶段就要考虑）

| 原则 | 落地含义 |
| --- | --- |
| 公开透明 | 采集个人数据时告知使用方式 |
| 最小化 | 只收集与目的相关、必要的数据；能匿名化/化名化就做 |
| 选择与控制 | 处理个人数据需用户同意，用户有充分控制权 |
| 数据安全 | 加密存储、安全传输，系统默认开启或采取保护措施 |
| 本地化处理 | 数据优先本地处理；必须上云时遵循最小化，不得默认上传 |
| 未成年人保护 | 面向未成年人或识别出未成年人时，按目标市场法律分析并在收集前征得监护人同意 |

🌟 应用上架时应用市场会按隐私规则校验，不满足条件无法上架。

### 五个常用方法

1. **隐私声明获取同意**：启动时用隐私声明弹窗说明敏感数据的使用与收集，同意后才获取。
2. **减少位置权限**：非强位置关联应用（导航、运动健康等）优先模糊定位。
3. **减少存储权限**：不要申请“所有照片/文件”级权限，用 `photoAccessHelper.PhotoViewPicker`（API 10+）让用户只授权所选内容；旧的 `@ohos.file.picker.PhotoViewPicker` 自 API 12 起废弃。
4. **动态申请敏感权限**：只申请必需权限，`reason` 写清用途。
5. **敏感数据加密**：存储与传输都加密，参考《应用数据安全》。

### 模糊定位：权限组合与精度（API 9 分界）

| target API level | 申请权限 | 结果 | 精度 |
| --- | --- | --- | --- |
| < 9 | `ohos.permission.LOCATION` | 成功 | 米级精准位置 |
| ≥ 9 | `ohos.permission.LOCATION` | **失败** | 无法获取位置 |
| ≥ 9 | `ohos.permission.APPROXIMATELY_LOCATION` | 成功 | 5 公里 |
| ≥ 9 | `APPROXIMATELY_LOCATION` + `LOCATION` | 成功 | 米级精准位置 |

实现三步：

```json5
// module.json5
"requestPermissions": [{
  "name": "ohos.permission.APPROXIMATELY_LOCATION",
  "reason": "$string:location_reason",
  "usedScene": { "abilities": ["EntryAbility"], "when": "always" }
}]
```

```typescript
const atManager = abilityAccessCtrl.createAtManager();
atManager.requestPermissionsFromUser(
  this.getUIContext().getHostContext(),
  ['ohos.permission.APPROXIMATELY_LOCATION']
).then((data) => {
  // data.authResults[0] === 0 表示已授权
});
```

```typescript
// 获取位置：模糊/精确定位接口相同，精度由授权结果决定
geoLocationManager.getCurrentLocation(requestInfo).then(result => { /* ... */ });
```

### 用 Picker 降低存储权限颗粒度（API 10+，photoAccessHelper.PhotoViewPicker）

```typescript
import { photoAccessHelper } from '@kit.MediaLibraryKit';

const options = new photoAccessHelper.PhotoSelectOptions();
options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
options.maxSelectNumber = 5;
const picker = new photoAccessHelper.PhotoViewPicker();
picker.select(options).then(result => {
  const uri = result.photoUris[0];   // 只拿到用户选中的文件
});
```

### 动态申请敏感权限（以相机为例）

```json5
// module.json5
"requestPermissions": [{
  "name": "ohos.permission.CAMERA",
  "reason": "$string:camera_reason",
  "usedScene": { "abilities": ["EntryAbility"], "when": "always" }
}]
```

```typescript
atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA'])
  .then(data => { /* authResults[0] === 0 表示授权 */ });
```

## 二、数据安全

### 风险等级：设备 SL1–SL5，数据 S1–S4

**设备等级**按安全能力（TEE、安全存储芯片等）划分：SL1 最低（智能穿戴常见），手机/平板通常高安全等级；SL1→SL5 在完整性保护、加密与数据保护、权限与访问控制、可信执行环境、漏洞防利用五个维度的要求逐级提高。

**数据等级**（官方表摘选）：

| 等级 | 定义 | 样例 |
| --- | --- | --- |
| S4 严重 | 法律定义的特殊数据类型；泄露造成重大不利影响 | 政治观点、宗教/哲学信仰、工会成员、基因/生物信息、健康与性生活、性取向、设备认证鉴权、信用卡等财务信息 |
| S3 高 | 泄露造成严峻不利影响 | 实时精确定位、运动轨迹 |
| S2 中 | 泄露造成严重不利影响 | 详细通信地址、姓名昵称 |
| S1 低 | 泄露造成有限不利影响 | 性别、国籍、用户申请记录 |

### 跨设备同步的访问控制矩阵

规则：**本端数据库的数据安全标签不得高于对端设备的设备安全等级**，否则不能同步。

| 设备安全级别 | 可同步的数据安全标签 |
| --- | --- |
| SL1 | S1 |
| SL2 | S1–S2 |
| SL3 | S1–S3 |
| SL4 | S1–S4 |
| SL5 | S1–S4 |

例：手表是 SL1，S1 数据库可同步，S2–S4 不能同步。

### 分级数据保护：el1–el4

| 加密区 | 访问策略 |
| --- | --- |
| el4 | 锁屏后 10 秒，解密密钥从内存丢弃；所有数据不可访问，需重新解锁 |
| el3 | 锁屏后已打开的文件可继续访问；文件一旦关闭（锁屏）就不能再访问，需重新解锁 |
| el2 | 开机后首次解锁即可访问；**第三方应用数据的默认数据保护类** |
| el1 | 直接启动模式与解锁后都可访问（设备级加密） |

- 无特殊需求应存 **el2**；时钟、闹铃、壁纸等需在解锁前访问的文件才放 **el1**。
- 切换加密区：`context.area = contextConstant.AreaMode.EL2`（或 `EL1`），再用 `context.filesDir` 拼路径。
- 应用沙箱按文件加密类型区分目录，防止路径穿越。

### HUKS：密钥全生命周期

HUKS（Universal KeyStore）提供密钥生成、导入、销毁、证明、协商、派生、加解密、签名验签与访问控制。业务不需要自己实现密码学算法和密钥访问控制模型。

AES-128 示例的关键配置：

```typescript
// 生成密钥
{ tag: HUKS_TAG_ALGORITHM, value: HUKS_ALG_AES }
{ tag: HUKS_TAG_KEY_SIZE, value: HUKS_AES_KEY_SIZE_128 }
{ tag: HUKS_TAG_PURPOSE, value: HUKS_KEY_PURPOSE_ENCRYPT | HUKS_KEY_PURPOSE_DECRYPT }
```

- 填充：`NoPadding` / `PKCS5`（8 字节填充）/ `PKCS7`（1–255 字节任意填充）。
- 分组模式：CBC、CTR、OFB、CFB 只需 `HUKS_TAG_IV`；GCM、CCM 需 `HUKS_TAG_NONCE`、`HUKS_TAG_ASSOCIATED_DATA`，并配置 `HUKS_TAG_IV`。
- 加解密流程：`generateKeyItem` → `initSession` → `finishSession`；解密配置与加密一致，仅密钥用途改为 `DECRYPT`。

### 敏感数据「二次加密」配方（体检报表案例）

官方把体检数据归为高风险，采用**两层**：先用 HUKS 对 JSON 字节数组加密，再把密文写入 el2 分级加密文件；读取时顺序相反。

- 录入：表单 → JSON 字符串 → 字节数组 → HUKS 加密 → `fileIo` 写入 el2 文件。
- 查看：`pushUrl` 的 `params` 传文件名 → `fileIo` 读密文 → HUKS 解密 → JSON 展示。
- 不同密级的数据建议**按密级分别序列化封装**，避免高密级数据在流动中泄到低密级设备。
- 日志里打印密文时可做 Base64 转码；正式代码可省略。

## 落地检查清单

- [ ] 隐私声明弹窗在首次采集前出现，拒绝后不采集
- [ ] 位置权限按场景选模糊/精准，target API ≥9 不单独申请 `LOCATION`
- [ ] 图片/文件用 Picker，不申请全量存储权限
- [ ] 敏感权限动态申请，`reason` 写明用途
- [ ] 数据按 S1–S4 分级，跨设备同步前比对 SL 等级
- [ ] 第三方应用数据默认落 el2；仅解锁前必需文件放 el1
- [ ] 口令、Token 等关键资产走 HUKS，不裸存
- [ ] 高风险数据采用 HUKS + 分级加密的二次加密
- [ ] 未成年人场景单独评估并取得监护人同意

## 官方原文与示例

- [应用隐私保护](https://developer.huawei.com/consumer/cn/doc/doccenter-architecture/bpta-app-privacy-protection)
- [应用数据安全](https://developer.huawei.com/consumer/cn/doc/doccenter-architecture/bpta-app-data-security)
- 示例：[AppPrivacyProtection](https://gitcode.com/HarmonyOS_Samples/AppPrivacyProtection)、[AppDataSecurity](https://gitcode.com/HarmonyOS_Samples/AppDataSecurity)
