// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Wetty Chat';

  @override
  String get tabChats => '聊天';

  @override
  String get tabSettings => '设置';

  @override
  String get login => '登录';

  @override
  String get loginInfo => '登录信息';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get securityQuestion => '安全问题';

  @override
  String get securityQuestionHint => '安全提问(未设置请忽略)';

  @override
  String get sqMothersName => '母亲的名字';

  @override
  String get sqGrandfathersName => '爷爷的名字';

  @override
  String get sqFathersBirthCity => '父亲出生的城市';

  @override
  String get sqTeachersName => '您其中一位老师的名字';

  @override
  String get sqComputerModel => '您个人计算机的型号';

  @override
  String get sqFavoriteRestaurant => '您最喜欢的餐馆名称';

  @override
  String get sqDriversLicenseLast4 => '驾驶执照最后四位数字';

  @override
  String get loginSuccess => '登录成功';

  @override
  String get loginFailed => '登录失败';

  @override
  String get missingFields => '缺少字段';

  @override
  String get processing => '处理中';

  @override
  String get ready => '准备就绪';

  @override
  String get newChat => '新聊天';

  @override
  String get chatName => '聊天名称';

  @override
  String get optional => '可选';

  @override
  String get create => '创建';

  @override
  String get chatCreated => '聊天已创建';

  @override
  String get noMessagesYet => '暂无消息';

  @override
  String get groupMembers => '群组成员';

  @override
  String get groupSettings => '群组设置';

  @override
  String get noMembers => '暂无成员';

  @override
  String get retry => '重试';

  @override
  String get settingsLanguage => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseCN => '简体中文';

  @override
  String get languageChineseTW => '繁體中文';

  @override
  String get settingsTextSize => '字体大小';

  @override
  String get settingsChat => '聊天';

  @override
  String get settingsShowAllTab => '显示「全部」标签';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsUser => '用户';

  @override
  String get settingsProfile => '个人资料';

  @override
  String get settingsNotifications => '通知';

  @override
  String get logOut => '退出登录';

  @override
  String get logOutConfirmTitle => '退出登录？';

  @override
  String get logOutConfirmMessage => '这会清除当前设备保存的登录状态。';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get error => '错误';

  @override
  String get close => '关闭';

  @override
  String get copied => '已复制';

  @override
  String get message => '消息';

  @override
  String get photos => '照片';

  @override
  String get gifs => 'GIF 动图';

  @override
  String get videos => '视频';

  @override
  String get files => '文件';

  @override
  String get reply => '回复';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get deleteMessageTitle => '删除消息？';

  @override
  String get deleteMessageBody => '此操作无法撤销。';

  @override
  String get voiceMessage => '语音消息';

  @override
  String get voiceWaitingForMicrophone => '正在等待麦克风…';

  @override
  String get voiceReleaseToSave => '松开发送到草稿';

  @override
  String get voiceSlideLeftToCancel => '左滑取消';

  @override
  String voiceUploadingProgress(int progress) {
    return '上传中 $progress%';
  }

  @override
  String get voiceRecordingUnsupported => '此设备不支持语音录制。';

  @override
  String get voiceMicrophonePermissionDenied => '需要麦克风权限才能录制语音。';

  @override
  String get voiceRecordingTooShort => '录音时间太短。';

  @override
  String get voiceRecordingStartFailed => '无法开始录音。';

  @override
  String get voiceMessageUploadFailed => '语音消息上传失败。';

  @override
  String get voiceMessageSendFailed => '语音消息发送失败。';

  @override
  String get deleteRecording => '删除录音';

  @override
  String get sendVoiceMessage => '发送语音消息';

  @override
  String get fontSize => '字体大小';

  @override
  String get messagesFontSize => '消息字体大小';

  @override
  String get sampleUser => '示例用户';

  @override
  String get fontSizePreviewMessage => '这是您的消息在聊天中的显示效果。';

  @override
  String get dateToday => '今天';

  @override
  String get dateYesterday => '昨天';

  @override
  String relativeMinutes(int count) {
    return '$count分钟前';
  }

  @override
  String relativeHours(int count) {
    return '$count小时前';
  }

  @override
  String get swipeActionMarkRead => '已读';

  @override
  String get swipeActionMarkUnread => '未读';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'Wetty Chat';

  @override
  String get tabChats => '聊天';

  @override
  String get tabSettings => '設定';

  @override
  String get login => '登入';

  @override
  String get loginInfo => '登入資訊';

  @override
  String get username => '使用者名稱';

  @override
  String get password => '密碼';

  @override
  String get securityQuestion => '安全問題';

  @override
  String get securityQuestionHint => '安全提問（未設定請忽略）';

  @override
  String get sqMothersName => '母親的名字';

  @override
  String get sqGrandfathersName => '爺爺的名字';

  @override
  String get sqFathersBirthCity => '父親出生的城市';

  @override
  String get sqTeachersName => '您其中一位老師的名字';

  @override
  String get sqComputerModel => '您個人電腦的型號';

  @override
  String get sqFavoriteRestaurant => '您最喜歡的餐館名稱';

  @override
  String get sqDriversLicenseLast4 => '駕駛執照最後四位數字';

  @override
  String get loginSuccess => '登入成功';

  @override
  String get loginFailed => '登入失敗';

  @override
  String get missingFields => '缺少欄位';

  @override
  String get processing => '處理中';

  @override
  String get ready => '準備就緒';

  @override
  String get newChat => '新聊天';

  @override
  String get chatName => '聊天名稱';

  @override
  String get optional => '選填';

  @override
  String get create => '建立';

  @override
  String get chatCreated => '聊天已建立';

  @override
  String get noMessagesYet => '暫無訊息';

  @override
  String get groupMembers => '群組成員';

  @override
  String get groupSettings => '群組設定';

  @override
  String get noMembers => '暫無成員';

  @override
  String get retry => '重試';

  @override
  String get settingsLanguage => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseCN => '简体中文';

  @override
  String get languageChineseTW => '繁體中文';

  @override
  String get settingsTextSize => '字型大小';

  @override
  String get settingsChat => '聊天';

  @override
  String get settingsShowAllTab => '顯示「全部」分頁';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsUser => '使用者';

  @override
  String get settingsProfile => '個人資料';

  @override
  String get settingsNotifications => '通知';

  @override
  String get logOut => '登出';

  @override
  String get logOutConfirmTitle => '登出？';

  @override
  String get logOutConfirmMessage => '這會清除目前裝置儲存的登入狀態。';

  @override
  String get cancel => '取消';

  @override
  String get ok => '確定';

  @override
  String get error => '錯誤';

  @override
  String get close => '關閉';

  @override
  String get copied => '已複製';

  @override
  String get message => '訊息';

  @override
  String get photos => '照片';

  @override
  String get gifs => 'GIF 動圖';

  @override
  String get videos => '影片';

  @override
  String get files => '檔案';

  @override
  String get reply => '回覆';

  @override
  String get edit => '編輯';

  @override
  String get delete => '刪除';

  @override
  String get deleteMessageTitle => '刪除訊息？';

  @override
  String get deleteMessageBody => '此操作無法復原。';

  @override
  String get voiceMessage => '語音訊息';

  @override
  String get voiceWaitingForMicrophone => '正在等待麥克風…';

  @override
  String get voiceReleaseToSave => '放開以儲存';

  @override
  String get voiceSlideLeftToCancel => '向左滑動取消';

  @override
  String voiceUploadingProgress(int progress) {
    return '上傳中 $progress%';
  }

  @override
  String get voiceRecordingUnsupported => '此裝置不支援語音錄製。';

  @override
  String get voiceMicrophonePermissionDenied => '需要麥克風權限才能錄製語音。';

  @override
  String get voiceRecordingTooShort => '錄音時間太短。';

  @override
  String get voiceRecordingStartFailed => '無法開始錄音。';

  @override
  String get voiceMessageUploadFailed => '語音訊息上傳失敗。';

  @override
  String get voiceMessageSendFailed => '語音訊息傳送失敗。';

  @override
  String get deleteRecording => '刪除錄音';

  @override
  String get sendVoiceMessage => '傳送語音訊息';

  @override
  String get fontSize => '字型大小';

  @override
  String get messagesFontSize => '訊息字型大小';

  @override
  String get sampleUser => '範例使用者';

  @override
  String get fontSizePreviewMessage => '這是您的訊息在聊天中的顯示效果。';

  @override
  String get dateToday => '今天';

  @override
  String get dateYesterday => '昨天';

  @override
  String relativeMinutes(int count) {
    return '$count分鐘前';
  }

  @override
  String relativeHours(int count) {
    return '$count小時前';
  }

  @override
  String get swipeActionMarkRead => '已讀';

  @override
  String get swipeActionMarkUnread => '未讀';
}
