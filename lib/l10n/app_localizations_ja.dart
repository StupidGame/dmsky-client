// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class SJa extends S {
  SJa([String locale = 'ja']) : super(locale);

  @override
  String get announcement => 'お知らせ';

  @override
  String get antenna => 'アンテナ';

  @override
  String get user => 'ユーザー';

  @override
  String get channel => 'チャンネル';

  @override
  String get timeline => 'タイムライン';

  @override
  String get sensitive => 'センシティブ';

  @override
  String get favorite => 'お気に入り';

  @override
  String get trend => 'トレンド';

  @override
  String get clip => 'クリップ';

  @override
  String get edit => '編集';

  @override
  String get editProfile => 'プロフィール編集';

  @override
  String get apply => '反映する';

  @override
  String get create => '作成';

  @override
  String get delete => '削除';

  @override
  String get search => '検索';

  @override
  String get detail => '詳細';

  @override
  String get save => '保存';

  @override
  String get hide => '隠す';

  @override
  String get note => 'ノート';

  @override
  String get mention => 'メンション';

  @override
  String get renote => 'リノート';

  @override
  String get quotedRenote => '引用';

  @override
  String get notification => '通知';

  @override
  String get list => 'リスト';

  @override
  String get explore => '探索';

  @override
  String get highlight => 'ハイライト';

  @override
  String get role => 'ロール';

  @override
  String get page => 'ページ';

  @override
  String get flash => 'Play';

  @override
  String get hashtag => 'ハッシュタグ';

  @override
  String get otherServers => '他のサーバー';

  @override
  String get follow => 'フォロー';

  @override
  String get following => 'フォロー中';

  @override
  String get managing => '管理中';

  @override
  String get done => '完了';

  @override
  String get public => 'パブリック';

  @override
  String get home => 'ホーム';

  @override
  String get local => 'ローカル';

  @override
  String get direct => 'ダイレクト';

  @override
  String get onlyLocal => 'ローカルのみ';

  @override
  String get remote => 'リモート';

  @override
  String get software => 'ソフトウェア';

  @override
  String get federatedPosts => '投稿';

  @override
  String get language => '言語';

  @override
  String get administrator => '管理者';

  @override
  String get contact => '連絡先';

  @override
  String get serverRules => 'サーバールール';

  @override
  String get tos => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get impressum => '運営者情報';

  @override
  String get willDelete => '削除しますか？';

  @override
  String get cancel => 'キャンセル';

  @override
  String get noneAction => '何もしない';

  @override
  String get pleaseInput => '入力してください';

  @override
  String get pleaseSelect => '選択してください';

  @override
  String get login => 'ログイン';

  @override
  String get settings => '設定';

  @override
  String get ad => '広告';

  @override
  String get customEmoji => 'カスタム絵文字';

  @override
  String get localTimeline => 'ローカルタイムライン';

  @override
  String get localTimelineAbbr => 'LTL';

  @override
  String get homeTimeline => 'ホームタイムライン';

  @override
  String get homeTimelineAbbr => 'HTL';

  @override
  String get socialTimeline => 'ソーシャルタイムライン';

  @override
  String get socialTimelineAbbr => 'STL';

  @override
  String get globalTimeline => 'グローバルタイムライン';

  @override
  String get roleTimeline => 'ロールタイムライン';

  @override
  String get customTimeline => 'サーバー独自タイムライン';

  @override
  String get server => 'サーバー';

  @override
  String get miAuth => 'MiAuth';

  @override
  String get apiKey => 'APIキー';

  @override
  String get contentWarning => '注釈';

  @override
  String get follower => 'フォロワー';

  @override
  String get sending => '送信中';

  @override
  String get antennaName => 'アンテナの名前';

  @override
  String get antennaSource => 'アンテナのソース';

  @override
  String get antennaSourceHome => 'ホーム';

  @override
  String get antennaSourceAll => 'すべて';

  @override
  String get antennaSourceUser => 'ユーザー';

  @override
  String get antennaSourceList => 'リスト';

  @override
  String get selectAntennaSource => 'ソースを選択';

  @override
  String get selectList => 'リストを選択';

  @override
  String get antennaSourceUserHintText => 'ユーザーネームを改行で区切って指定します';

  @override
  String get addUser => 'ユーザーを追加';

  @override
  String get keywords => 'キーワード';

  @override
  String get antennaSourceKeywordsHintText =>
      'スペースで区切った単語はAND条件で、改行で区切った行はOR条件で扱います';

  @override
  String get excludeKeywords => '除外キーワード';

  @override
  String get antennaSourceExcludeKeywordsHintText =>
      'スペースで区切った単語はAND条件で、改行で区切った行はOR条件で扱います';

  @override
  String get discriminateUpperLower => '大文字と小文字を区別する';

  @override
  String get receiveReplies => 'リプライを受信する';

  @override
  String get receiveOnlyFiles => 'ファイル付きのノートのみ受信する';

  @override
  String get receiveLocal => 'ローカルのみ受信する';

  @override
  String get receiveLocalAvailability => 'ローカルのみの指定はMisskey 2023.10.2以降で有効です。';

  @override
  String get confirmDeletingAntenna => 'このアンテナを削除しますか？';

  @override
  String channelJoinningCounts(int usersCount) {
    final intl.NumberFormat usersCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String usersCountString = usersCountNumberFormat.format(usersCount);

    return '$usersCountString人が参加中';
  }

  @override
  String channelNotes(int notesCount) {
    final intl.NumberFormat notesCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String notesCountString = notesCountNumberFormat.format(notesCount);

    return '$notesCountString投稿';
  }

  @override
  String channelLastNotedAt(String lastNotedAt) {
    return '$lastNotedAt に更新';
  }

  @override
  String get thisChannelIsArchived => 'このチャンネルはアーカイブされています';

  @override
  String get favorited => 'お気に入り中';

  @override
  String get willFavorite => 'お気に入りに追加しますか？';

  @override
  String get willFollow => 'フォローしますか？';

  @override
  String get channelInformation => 'チャンネル情報';

  @override
  String channelStatistics(int notesCount, int usersCount, String lastNotedAt) {
    final intl.NumberFormat notesCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String notesCountString = notesCountNumberFormat.format(notesCount);
    final intl.NumberFormat usersCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String usersCountString = usersCountNumberFormat.format(usersCount);

    return '$notesCountString 投稿 / $usersCountString 人が参加中 / $lastNotedAt に更新';
  }

  @override
  String get notImplemented => '作成中';

  @override
  String get createClip => 'クリップを作成';

  @override
  String get confirmDeleteClip => 'このクリップを削除しますか？';

  @override
  String get clipName => 'クリップ名';

  @override
  String get clipDescription => '説明（省略可）';

  @override
  String get alreadyAddedClip => 'このノートはすでにクリップに追加されています';

  @override
  String get deleteClip => 'クリップから削除する';

  @override
  String get thanksForReport => '内容が送信されました。ご報告ありがとうございました。';

  @override
  String reportAbuseOf(String userName) {
    return '$userName を通報する';
  }

  @override
  String get pleaseInputReasonWhyAbuse =>
      '通報理由の詳細を記入してください。対象のノートがある場合はそのURLも記入してください。';

  @override
  String get reportAbuse => '通報する';

  @override
  String get closeTweet => 'ツイートを閉じる';

  @override
  String get closePlayer => 'プレイヤーを閉じる';

  @override
  String get doneCopy => 'コピーしました';

  @override
  String mutedNotePlaceholder(String userName) {
    return '\$1の投稿は非表示になっています';
  }

  @override
  String get showCw => '内容を表示';

  @override
  String get showReactionedNote => '続きを表示';

  @override
  String get showLongText => '続きを表示';

  @override
  String get showMoreFiles => '続きを表示';

  @override
  String otherReactions(int reactionCounts) {
    final intl.NumberFormat reactionCountsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String reactionCountsString = reactionCountsNumberFormat.format(
      reactionCounts,
    );

    return 'ほか$reactionCountsString個';
  }

  @override
  String get confirmDeleteReaction => 'リアクションを取り消しますか？';

  @override
  String get cancelReaction => '取り消す';

  @override
  String get renotedBy => 'がリノート';

  @override
  String get selfRenotedBy => 'がセルフリノート';

  @override
  String get savedImage => '画像を保存しました';

  @override
  String get tapToShow => 'タップして表示';

  @override
  String get copyContents => '内容をコピー';

  @override
  String get copyLinks => 'リンクをコピー';

  @override
  String get copyName => 'ユーザー名をコピー';

  @override
  String get copyUserScreenName => 'ユーザースクリーン名をコピー';

  @override
  String get openBrowsers => 'ブラウザで開く';

  @override
  String get openBrowsersAsRemote => 'ブラウザでリモート先を開く';

  @override
  String get openInAnotherAccount => '別のアカウントで開く';

  @override
  String get openNoteInBrowsers => 'ブラウザでノートを開く';

  @override
  String get changeFullScreen => 'フルスクリーンに切り替え';

  @override
  String get shareNotes => 'ノートを共有';

  @override
  String get deleteFavorite => 'お気に入り解除';

  @override
  String get notesAfterRenote => 'リノート直後のノート';

  @override
  String get deletedRecreate => '削除してなおす';

  @override
  String get confirmDeletedRecreate =>
      'このノートを削除して再投稿しますか？リアクション、リノート、返信は引き継がれません。';

  @override
  String get deleteRenote => 'リノートを解除する';

  @override
  String get confirmDelete => '本当に削除しますか？';

  @override
  String get doDeleting => '削除する';

  @override
  String confirmPoll(String choiced) {
    return '$choicedに投票しますか？';
  }

  @override
  String votesCount(int votes) {
    final intl.NumberFormat votesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String votesString = votesNumberFormat.format(votes);

    return '($votesString票)';
  }

  @override
  String totalVotesCount(int votes) {
    final intl.NumberFormat votesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String votesString = votesNumberFormat.format(votes);

    return '計$votesString票・';
  }

  @override
  String get finished => '終了済み';

  @override
  String get openResult => '結果を見る';

  @override
  String get doVoting => '投票する';

  @override
  String get alreadyVoted => '投票済み';

  @override
  String remainDiffer(String differ) {
    return 'あと$differ';
  }

  @override
  String get renoted => 'リノートしました。';

  @override
  String renoteInSpecificChannel(String channelName) {
    return '$channelName内にリノート';
  }

  @override
  String quotedRenoteInSpecificChannel(String channelName) {
    return '$channelName内に引用';
  }

  @override
  String get renoteInChannel => 'チャンネルへリノート';

  @override
  String get renoteInOtherChannel => '別のチャンネルにリノート';

  @override
  String get quotedRenoteInChannel => 'チャンネルへ引用';

  @override
  String get quotedRenoteInOtherChannel => '別のチャンネルに引用';

  @override
  String get renotedUsers => 'リノートしたユーザー';

  @override
  String get otherComplementReactions => '他のリアクション';

  @override
  String get openAsOtherAccount => '開くアカウントを選択';

  @override
  String get pickColor => '色を選択';

  @override
  String get decideColor => 'これにする';

  @override
  String accountSetting(String accountName) {
    return '$accountNameの設定';
  }

  @override
  String get chooseFile => 'ファイルを選択';

  @override
  String get uploadFile => 'アップロード';

  @override
  String get fromDrive => 'ドライブから';

  @override
  String get fileName => 'ファイル名';

  @override
  String get randomizeFileName => 'ファイル名をランダムにする';

  @override
  String get caption => 'キャプション';

  @override
  String get sensitiveSubTitle => '閲覧注意の設定を外した場合でも、自動で閲覧注意にマークされることがあります。';

  @override
  String get replyNotePlaceholder => '返信内容を入力';

  @override
  String get defaultNotePlaceholder => '今、何を投稿しますか？';

  @override
  String get hasMediaButCannotEdit => 'メディアがあります（編集はできません）';

  @override
  String get hasVoteButCannotEdit => '投票があります（編集はできません）';

  @override
  String followedNotification(String userName) {
    return '$userNameにフォローされました';
  }

  @override
  String followRequestAcceptedNotification(String userName) {
    return '\$1がフォローを許可しました';
  }

  @override
  String receiveFollowRequestNotification(String userName) {
    return '$userNameからフォローリクエストが届きました';
  }

  @override
  String get achievementEarnedNotification => '実績を獲得しました';

  @override
  String get testNotification => 'テスト通知';

  @override
  String get renotedUsersInNotification => 'リノートしたユーザー';

  @override
  String get reactionUsersInNotification => 'リアクションしたユーザー';

  @override
  String get finishedVotedNotification => '投票が終了しました';

  @override
  String get scheduledNotePostedNotification => '予約投稿が投稿されました';

  @override
  String get scheduledNotePostFailedNotification => '予約投稿に失敗しました';

  @override
  String renoteAndReactionsNotification(
    String? reactionUser,
    String? renotedUser,
  ) {
    return '$reactionUserさんがリアクションし、$renotedUserさんがリノートしました';
  }

  @override
  String renoteNotification(String? renoteUser) {
    return '$renoteUserさんがリノートしました';
  }

  @override
  String reactionNotification(String? reactionUser) {
    return '$reactionUserさんがリアクションしました';
  }

  @override
  String notedNotification(String notedUser) {
    return '$notedUserさんが投稿しました';
  }

  @override
  String roleAssignedNotification(String role) {
    return 'ロール「\$1」が付与されました';
  }

  @override
  String get appNotification => 'アプリからの通知';

  @override
  String get someoneLogined => '自分のアカウントへのログインがありました';

  @override
  String get unknownNotification => '不明な種類の通知です';

  @override
  String get createTokenNotification => 'アクセストークンが作成されました';

  @override
  String get chatRoomInvitationReceivedNotification => 'チャットルームに招待されました';

  @override
  String messageForFollower(String message) {
    return 'フォロワーへ 「$message」';
  }

  @override
  String get notificationAll => 'すべて';

  @override
  String get notificationForMe => 'メンション';

  @override
  String get notificationDirect => 'ダイレクト';

  @override
  String get editPhoto => '写真編集';

  @override
  String get customEmojiLicensedBy => 'このカスタム絵文字はこのようにライセンスされています。';

  @override
  String get customEmojiLicensedByNone => '※このカスタム絵文字に対してライセンスは設定されていません。';

  @override
  String get cancelEmojiChoosing => '選択をキャンセル';

  @override
  String get doneEmojiChoosing => 'この絵文字を使用する';

  @override
  String get confirmSavingPhoto => '写真を保存しますか？';

  @override
  String get doneEditingPhoto => '保存する';

  @override
  String get continueEditingPhoto => '編集を続ける';

  @override
  String get disabledUsingSensitiveCustomEmoji => 'ここではセンシティブなカスタム絵文字を使用できません';

  @override
  String get markAsSensitive => 'センシティブとしてマークする';

  @override
  String get publicSubTitle => 'みんなに公開';

  @override
  String get homeSubTitle => 'ホームタイムラインのみに公開';

  @override
  String get followersSubTitle => '自分のフォロワーのみに公開';

  @override
  String get specifiedSubTitle => '選択したユーザーのみに公開';

  @override
  String get favoriteAll => 'すべて';

  @override
  String get favoriteLikeOnly => 'いいねのみ';

  @override
  String get favoriteLikeOnlyForRemote => 'リモートからはいいねのみ';

  @override
  String get favoriteNonSensitiveOnly => '非センシティブのみ';

  @override
  String get favoriteNonSensitiveOnlyAndLikeOnlyForRemote =>
      '非センシティブのみ（リモートからはいいねのみ）';

  @override
  String get replyTo => '返信先';

  @override
  String get addChoice => '増やす';

  @override
  String choiceNumber(int choice) {
    final intl.NumberFormat choiceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String choiceString = choiceNumberFormat.format(choice);

    return '回答$choiceString';
  }

  @override
  String get canMultipleChoice => '複数回答';

  @override
  String get disabledInHashtag => 'これらはハッシュタグでは機能しません。';

  @override
  String joiningHashtagUsers(int usersCount) {
    final intl.NumberFormat usersCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String usersCountString = usersCountNumberFormat.format(usersCount);

    return '$usersCountString<small>人</small>';
  }

  @override
  String get searchVoteTab => 'アンケート';

  @override
  String allocatedRolesCount(int usersCount) {
    final intl.NumberFormat usersCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String usersCountString = usersCountNumberFormat.format(usersCount);

    return '$usersCountString<small>人</small>';
  }

  @override
  String get pageWrittenBy => 'このページを書いた人';

  @override
  String pageCreatedAt(DateTime createdAt) {
    final intl.DateFormat createdAtDateFormat = intl.DateFormat.yMMMd(
      localeName,
    );
    final String createdAtString = createdAtDateFormat.format(createdAt);

    return '作成日: $createdAtString';
  }

  @override
  String pageUpdatedAt(DateTime updatedAt) {
    final intl.DateFormat updatedAtDateFormat = intl.DateFormat.yMMMd(
      localeName,
    );
    final String updatedAtString = updatedAtDateFormat.format(updatedAt);

    return '更新日: $updatedAtString';
  }

  @override
  String get unsupportedPage => 'DMSKY Clientが対応していないページです。ブラウザーで開いてください。';

  @override
  String get canNotFavoriteMyPage => '自分のページはお気に入りに登録できません';

  @override
  String get activeAnnouncements => '公開中';

  @override
  String get inactiveAnnouncements => '過去のお知らせ';

  @override
  String get announcementsForYou => 'あなた宛て';

  @override
  String confirmAnnouncementsRead(Object title) {
    return '「\$1」を確認しましたか？';
  }

  @override
  String get readAnnouncement => '確認しました';

  @override
  String get didNotReadAnnouncement => 'あとで確認する';

  @override
  String get onlineUsers => 'サーバーオンライン人数';

  @override
  String onlineUsersCount(int usersCount, Object n) {
    final intl.NumberFormat usersCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String usersCountString = usersCountNumberFormat.format(usersCount);

    return '$usersCountString<small>人</small>';
  }

  @override
  String get cpuUsageRate => 'CPU使用率';

  @override
  String get memoryUsageRate => 'メモリ使用率';

  @override
  String get responseTime => '応答時間';

  @override
  String get inboxQueue => 'ジョブキュー (Inbox queue)';

  @override
  String get inboxProcessQueue => 'Process';

  @override
  String get inboxActiveQueue => 'Active';

  @override
  String get inboxDelayedQueue => 'Delayed';

  @override
  String get inboxWaitingQueue => 'Waiting';

  @override
  String get deliverQueue => 'ジョブキュー (Deliver queue)';

  @override
  String get deliverProcessQueue => 'Process';

  @override
  String get deliverActiveQueue => 'Active';

  @override
  String get deliverDelayedQueue => 'Delayed';

  @override
  String get deliverWaitingQueue => 'Waiting';

  @override
  String get persons => '人';

  @override
  String get milliSeconds => 'ミリ秒';

  @override
  String get pinnedUser => 'ピン留め';

  @override
  String get sort => '並び順';

  @override
  String joiningServerUsers(int usersCount) {
    final intl.NumberFormat usersCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String usersCountString = usersCountNumberFormat.format(usersCount);

    return '$usersCountString人が参加中';
  }

  @override
  String get serverInformation => 'サーバー情報';

  @override
  String get loginAsMiAuth => 'MiAuthでログイン';

  @override
  String get loginAsAPIKey => 'APIキーでログイン';

  @override
  String get authorizate => '認証する';

  @override
  String get reauthorizate => '再認証する';

  @override
  String get chooseLoginServer => 'ログインするサーバーを選んでください';

  @override
  String get didAuthorize => '認証しました';

  @override
  String get thrownConnectionError => '通信に失敗しました。';

  @override
  String get thrownConnectionTimeout => 'タイムアウトしました。';

  @override
  String get thrownWebSocketException => '通信に失敗しました。';

  @override
  String get thrownTimeoutException => 'サーバーが応答してくれませんでした。';

  @override
  String get thrownUnknownError => '不明なエラー';

  @override
  String get thrownError => 'エラーが発生しました';

  @override
  String get unsupportedServer => '非対応のサーバーです';

  @override
  String get future => '未来';

  @override
  String get justNow => 'たったいま';

  @override
  String secondsAgo(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString秒前';
  }

  @override
  String minutesAgo(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString分前';
  }

  @override
  String hoursAgo(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString時間前';
  }

  @override
  String daysAgo(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString日前';
  }

  @override
  String yearsAgo(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString年前';
  }

  @override
  String inSeconds(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString秒後';
  }

  @override
  String inMinutes(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString分後';
  }

  @override
  String inHours(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString時間後';
  }

  @override
  String inDays(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString日後';
  }

  @override
  String inYears(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString年後';
  }

  @override
  String nSeconds(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString秒',
    );
    return '$_temp0';
  }

  @override
  String nMinutes(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString分',
    );
    return '$_temp0';
  }

  @override
  String nHours(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString時間',
    );
    return '$_temp0';
  }

  @override
  String nDays(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString日',
    );
    return '$_temp0';
  }

  @override
  String get lightMode => 'ライトモード';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get syncWithSystem => 'デバイスの設定にしたがう';

  @override
  String get hideSensitiveMedia => '閲覧注意のメディアは隠す';

  @override
  String get showSensitiveMedia => '閲覧注意のメディアを隠さない';

  @override
  String get hideAllMedia => '常にメディアを隠す';

  @override
  String get removeSensitiveNotes => 'TLで閲覧注意つきのノートを表示しない';

  @override
  String get enableInfiniteScroll => '自動で次を読み込む';

  @override
  String get disableInfiniteScroll => '自動で読み込まない';

  @override
  String get top => '上';

  @override
  String get bottom => '下';

  @override
  String get systemEmoji => '標準';

  @override
  String invalidServer(String server) {
    return '$server はサーバーとして認識できませんでした。\nサーバーには、「misskey.io」などを入力してください。';
  }

  @override
  String serverIsNotMisskey(String server) {
    return '$server はMisskeyサーバーとして認識できませんでした。';
  }

  @override
  String softwareNotSupported(String software) {
    return 'DMSKY Clientは$softwareに未対応です。';
  }

  @override
  String softwareNotCompatible(String software, String version) {
    return 'DMSKY Clientと互換性のないソフトウェアです。\n$software $version';
  }

  @override
  String alreadyLoggedIn(String acct) {
    return '$acctで既にログインしています';
  }

  @override
  String get importFromThisFolder => 'このフォルダーからインポートする';

  @override
  String get exportedFileNotFound => 'このフォルダーにDMSKY Clientの設定ファイルが見つかりません';

  @override
  String get importCompleted => 'インポートが完了しました';

  @override
  String get exportToThisFolder => 'このフォルダーに保存する';

  @override
  String get confirmOverwrite => '同名のファイルが存在します。上書きしますか？';

  @override
  String get overwrite => '上書きする';

  @override
  String get exportedFileComment => 'DMSKY Client設定ファイル';

  @override
  String get exportCompleted => 'エクスポートが完了しました';

  @override
  String get cannotOpenLocalOnlyNoteFromRemote => 'ローカル限定のノートは他のサーバーから開けません';

  @override
  String get unlimited => '無期限';

  @override
  String get specifyByDate => '日時指定';

  @override
  String get specifyByDuration => '期間指定';

  @override
  String get seconds => '秒';

  @override
  String get minutes => '分';

  @override
  String get hours => '時間';

  @override
  String get days => '日';

  @override
  String get pleaseInputSomething => '内容を入力してください';

  @override
  String get pleaseAddVoteChoice => '投票の選択肢を2つ以上入力してください';

  @override
  String get pleaseSpecifyExpirationDate => '投票の終了日時を指定してください';

  @override
  String get pleaseSpecifyExpirationDuration => '投票期間を指定してください';

  @override
  String get cannotMentionToRemoteInLocalOnlyNote =>
      'ローカル限定の投稿に、他のサーバーのユーザーがメンションされています';

  @override
  String cannotPublicReplyToPrivateNote(String visibility) {
    return '返信元の公開範囲が$visibilityのため、公開投稿にはできません';
  }

  @override
  String get cannotPublicNoteBySilencedUser =>
      'サイレンスロールになっているため、パブリックで投稿することはできません。';

  @override
  String get cannotFederateNoteToChannel => 'チャンネルの投稿は連合に配信できません。';

  @override
  String get cannotFederateReplyToLocalOnlyNote =>
      '返信元の投稿がローカル限定のため、この投稿もローカル限定にする必要があります。';

  @override
  String get cannotFederateRenoteToLocalOnlyNote =>
      'リノート元の投稿がローカル限定のため、この投稿もローカル限定にする必要があります。';

  @override
  String get unexpectedSensitive => 'アップロードしたファイルがサーバーによってセンシティブと判定されました。どのように扱いますか？';

  @override
  String get staySensitive => 'センシティブ設定を維持';

  @override
  String get unsetSensitive => 'センシティブ設定を解除';

  @override
  String noteCreatedAt(String createdAt) {
    return '投稿時間: $createdAt';
  }

  @override
  String get accept => '許可';

  @override
  String get reject => '拒否';

  @override
  String get generalSettings => '全般設定';

  @override
  String get accountSettings => 'アカウント設定';

  @override
  String get tabSettings => 'タブ設定';

  @override
  String get settingsImportAndExport => '設定のインポート・エクスポート';

  @override
  String get aboutMiria => 'このアプリについて';

  @override
  String get quitAccountSettings => 'アカウント設定を終了';

  @override
  String get packageName => 'パッケージ名';

  @override
  String get version => 'バージョン';

  @override
  String get developer => '開発者';

  @override
  String get officialWebSite => '公式ページ';

  @override
  String get openSourceLicense => 'オープンソースライセンス';

  @override
  String get showLicense => 'ライセンスを表示する';

  @override
  String get general => '全般';

  @override
  String get displayOfSensitiveNotes => '閲覧注意のついたノートの表示';

  @override
  String get infiniteScroll => '一覧の自動更新';

  @override
  String get enableAnimatedMfm => '動きのあるMFM';

  @override
  String get enableAnimatedMfmDescription => '動きのあるMFMを有効にします。';

  @override
  String get collapseNotes => 'ノートの省略';

  @override
  String get collapseReactionedRenotes => 'リアクション済みノートのリノートを省略します。';

  @override
  String get collapseLongNotes => '長いノートを省略します。';

  @override
  String get tabPosition => 'タブの位置';

  @override
  String tabPositionDescription(String tabPosition) {
    return '$tabPositionに表示する';
  }

  @override
  String get theme => 'テーマ';

  @override
  String get themeForLightMode => 'ライトモードで使うテーマ';

  @override
  String get themeForDarkMode => 'ダークモードで使うテーマ';

  @override
  String themeIsh(String theme) {
    return '$theme風';
  }

  @override
  String get selectLightOrDarkMode => 'ライトモードとダークモードの使い分け';

  @override
  String get reaction => 'リアクション';

  @override
  String get emojiTapReaction => 'ノート内の絵文字タップでリアクションする';

  @override
  String get emojiTapReactionDescription =>
      'ノート内の絵文字をタップしてリアクションします。MFMや外部サーバーの絵文字の場合うまく機能しないことがあります。';

  @override
  String get emojiStyle => '絵文字のスタイル';

  @override
  String get fontStandard => 'フォント（標準）';

  @override
  String get fontSerif => 'フォント（\$[font.serif 用）';

  @override
  String get fontMonospace => 'フォント （\$[font.monospace やコードブロック 用）';

  @override
  String get fontCursive => 'フォント （\$[font.cursive 用）';

  @override
  String get fontFantasy => 'フォント （\$[font.fantasy 用）';

  @override
  String get fontSize => 'フォントサイズ';

  @override
  String get systemFont => 'システム標準';

  @override
  String get cache => 'キャッシュ';

  @override
  String get cacheSize => 'キャッシュサイズ';

  @override
  String get cacheSizeError => '取得に失敗しました';

  @override
  String get clearCache => 'キャッシュを削除';

  @override
  String get getCacheSize => 'サイズを取得';

  @override
  String get selectFolder => 'フォルダー選択';

  @override
  String get settingsFileManagement => '設定ファイルの管理';

  @override
  String get importAndExportSettingsDescription =>
      '現在の設定から、アカウントのログイン情報を除くすべての設定を設定ファイルに出力して管理することができます。設定ファイルは、指定したアカウントの「ドライブ」内に保存されます。';

  @override
  String get importSettings => 'インポート';

  @override
  String get importSettingsDescription =>
      '全般設定と、この端末でログインしているアカウントに対応する設定が読み込まれます。';

  @override
  String get pleaseSelectAccount => 'アカウントを選択してください';

  @override
  String get select => '選択';

  @override
  String get exportSettings => 'エクスポート';

  @override
  String get exportSettingsDescription =>
      '全般設定と、この端末でログインしているすべてのアカウントの設定を設定ファイルに保存します。';

  @override
  String get pleaseSelectAccountToExportSettings => '設定ファイルの保存先アカウントを選択してください';

  @override
  String get selectAntenna => 'アンテナ選択';

  @override
  String get selectChannel => 'チャンネル選択';

  @override
  String get selectIcon => 'アイコンを選択';

  @override
  String get standardIcon => '標準';

  @override
  String get emojiIcon => 'カスタム絵文字';

  @override
  String get selectRole => 'ロール選択';

  @override
  String get account => 'アカウント';

  @override
  String get tabType => 'タブの種類';

  @override
  String get tabName => 'タブの名前';

  @override
  String get icon => 'アイコン';

  @override
  String get displayRenotes => 'リノートを表示する';

  @override
  String get includeReplies => '返信も入れる';

  @override
  String get includeRepliesAvailability => 'Misskey v2023.10.1以降の機能です。';

  @override
  String get mediaOnly => 'ファイルのみにする';

  @override
  String get subscribeNotes => 'リアクションや投票数を自動更新する';

  @override
  String get subscribeNotesDescription =>
      'オフにすると、リアクションや投票数が自動更新されませんが、バッテリー消費を抑えられることがあります。';

  @override
  String get pleaseSelectTabType => 'タブの種類を選択してください。';

  @override
  String get pleaseSelectIcon => 'アイコンを選択してください。';

  @override
  String get pleaseSelectChannel => 'チャンネルを選択してください。';

  @override
  String get pleaseSelectList => 'リストを選択してください。';

  @override
  String get pleaseSelectAntenna => 'アンテナを選択してください。';

  @override
  String get pleaseSelectRole => 'ロールを選択してください。';

  @override
  String get customChannelName => 'チャンネル名';

  @override
  String get customApiPath => 'POSTエンドポイントのパス';

  @override
  String get customTimelineParameters => 'パラメータ (JSON)';

  @override
  String get customPresetSelect => 'プリセットから選択';

  @override
  String get reactionDeck => 'リアクションデッキ';

  @override
  String get wordMute => 'ワードミュート';

  @override
  String get hardWordMute => 'ハードワードミュート';

  @override
  String get instanceMute => 'インスタンスミュート';

  @override
  String get mutedUsers => 'ミュート済みユーザー';

  @override
  String get blockedUsers => 'ブロック済みユーザー';

  @override
  String confirmUnblockUser(String userName) {
    return '\$1のブロックを解除しますか？';
  }

  @override
  String confirmUnmuteUser(String userName) {
    return '\$1のミュートを解除しますか？';
  }

  @override
  String get unblock => 'ブロック解除';

  @override
  String get unmute => 'ミュート解除';

  @override
  String get cacheSettings => 'キャッシュ設定';

  @override
  String get hideConditionalNotes => '指定した条件のノートをタイムラインから隠します。';

  @override
  String get muteSettingDescription =>
      'スペースで区切るとAND指定になり、改行で区切るとOR指定になります。\nキーワードをスラッシュで囲むと正規表現になります。';

  @override
  String get refreshOnTabChange => 'タブ切替時に毎回読み込む';

  @override
  String get refreshOnLaunch => '起動時に毎回読み込む';

  @override
  String get refreshOnceADay => '1日に1回読み込む';

  @override
  String get userCache => '自分自身の情報（通知などを含みます）';

  @override
  String get emojiCache => '絵文字の情報';

  @override
  String get serverCache => 'サーバーの情報';

  @override
  String get instanceMuteDescription1 => '設定したサーバーのノートを隠します。';

  @override
  String get instanceMuteDescription2 =>
      'ミュートしたサーバーのユーザーへの返信を含めて、設定したサーバーの全てのノートとリノートをミュートします。\n改行で区切って設定します。';

  @override
  String get reactionMute => 'リアクションミュート';

  @override
  String get reactionMuteDescription =>
      '改行区切りで :emoji: または :emoji@host: の形式で入力します。@host のみも受け付け、この場合該当ホストすべてを対象とします。';

  @override
  String get bulkAddReactions => '一括追加';

  @override
  String get bulkAddReactionsDescription1 =>
      'お使いのブラウザでリアクションデッキをコピーしたいアカウントにログインしてください';

  @override
  String get bulkAddReactionsDescription2 =>
      '同じブラウザで以下のURLにアクセスして「値 (JSON)」の内容をすべて選択してコピーしてください';

  @override
  String get bulkAddReactionsDescription2ForEmojiPalette =>
      '同じブラウザで以下のURLにアクセスして絵文字パレットをコピーしてください';

  @override
  String get bulkAddReactionsDescription3 => 'コピーしたものを下のテキストボックスに貼り付けてください';

  @override
  String get bulkAddMutedReactions => 'ミュート設定をインポート';

  @override
  String get bulkAddMutedReactionsDescription1 =>
      'お使いのブラウザでミュート設定をコピーしたいアカウントにログインしてください';

  @override
  String get bulkAddMutedReactionsDescription2 =>
      '同じブラウザで以下のURLにアクセスしてミュート設定の内容をコピーしてください';

  @override
  String get bulkAddMutedReactionsDescription3 =>
      'コピーしたものを下のテキストボックスに貼り付けてください';

  @override
  String get importMutedReactions => 'ミュート設定をインポート';

  @override
  String get pasteHere => 'ここに貼り付け';

  @override
  String get invalidInput => '入力が有効な値ではありません';

  @override
  String get clear => 'クリア';

  @override
  String get copy => 'コピー';

  @override
  String get editReactionDeckDescription => '長押しして並び変え、押して削除、＋を押して追加します。';

  @override
  String get confirmClearReactionDeck => 'すでに設定済みのリアクションデッキをいったんすべてクリアしますか？';

  @override
  String get clearReactionDeck => 'クリアする';

  @override
  String accountGeneralSettings(String accountName) {
    return '$accountName 全般設定';
  }

  @override
  String get privacy => 'プライバシー';

  @override
  String get setDefaultNoteVisibility => 'デフォルトの公開範囲を設定します。';

  @override
  String get noteVisibility => 'ノート公開範囲';

  @override
  String get disableFederation => '連合をなしにします';

  @override
  String get disableFederationDescription =>
      '連合をなしにしても、非公開になりません。ほとんどの場合、連合なしにする必要はありません。';

  @override
  String get reactionAcceptance => 'リアクションの受け入れ';

  @override
  String get reactionAcceptanceAll => '全部';

  @override
  String get forceShowAds => '広告を常に表示する';

  @override
  String get wordMuteDescription =>
      'スペースで区切るとAND指定になり、改行で区切るとOR指定になります。\nキーワードをスラッシュで囲むと正規表現になります。\nただし、Misskey Webと正規表現の仕様が異なるため、DMSKY Clientで動作する正規表現がMisskey Webで動作しなかったり、その逆が発生することがあります。';

  @override
  String get selectAccountToShare => '共有するアカウントを選択';

  @override
  String get createAntenna => 'アンテナを作成';

  @override
  String get memo => 'メモ';

  @override
  String get memoDescription => 'メモする内容を入力してください';

  @override
  String get confirmCreateBlock => 'このユーザーをブロックしますか？';

  @override
  String get createBlock => 'ブロックする';

  @override
  String get addToList => 'リストに追加';

  @override
  String get addToAntenna => 'アンテナに追加';

  @override
  String get searchNote => 'ノートを検索';

  @override
  String get deleteRenoteMute => 'リノートのミュートを解除する';

  @override
  String get createRenoteMute => 'リノートをミュートする';

  @override
  String get deleteMute => 'ミュートを解除する';

  @override
  String get createMute => 'ミュートする';

  @override
  String get deleteBlock => 'ブロックを解除する';

  @override
  String get minutes10 => '10分間';

  @override
  String get hours1 => '1時間';

  @override
  String get day1 => '1日';

  @override
  String get week1 => '1週間';

  @override
  String get selectDuration => '期限を選択してください。';

  @override
  String get confirmUnfollow => 'フォローを解除しますか？';

  @override
  String get deleteFollow => '解除する';

  @override
  String get renoteMuting => 'リノートのミュート中';

  @override
  String get muting => 'ミュート中';

  @override
  String get blocking => 'ブロック中';

  @override
  String get followed => 'フォローされています';

  @override
  String get unfollow => 'フォロー解除';

  @override
  String get followRequestPending => 'フォロー許可待ち';

  @override
  String get followRequest => 'フォロー申請';

  @override
  String get createFollow => 'フォローする';

  @override
  String get refreshing => '更新中';

  @override
  String get remoteUserCaution => 'リモートユーザーのため、情報が不完全です。';

  @override
  String get showServerInformation => 'サーバー情報を表示';

  @override
  String get location => '場所';

  @override
  String get registeredDate => '登録日';

  @override
  String get birthday => '誕生日';

  @override
  String get includeRepliesShort => '返信つき';

  @override
  String get mediaOnlyShort => 'ファイルつき';

  @override
  String get displayRenotesShort => 'リノートも';

  @override
  String get showNotesBeforeThisDate => 'この日までを表示';

  @override
  String get showNotesBeforeThisTime => 'この時間までを表示';

  @override
  String get userHighlightAvailability => 'ハイライトはMisskey 2023.10.0以降の機能です。';

  @override
  String get userInfomation => 'アカウント情報';

  @override
  String get userInfomationLocal => 'アカウント情報（ローカル）';

  @override
  String get userInfomationRemote => 'アカウント情報（リモート）';

  @override
  String get userNotes => 'ノート';

  @override
  String get userNotesLocal => 'ノート（ローカル）';

  @override
  String get userNotesRemote => 'ノート（リモート）';

  @override
  String get userReactions => 'リアクション';

  @override
  String get userPages => 'ページ';

  @override
  String get userPlays => 'Play';

  @override
  String get userPlaysAvailability => 'この機能はMisskey 2023.9以降でのみ使用できます。';

  @override
  String get createList => 'リストを作成';

  @override
  String get listName => 'リスト名';

  @override
  String get members => 'メンバー';

  @override
  String listCapacity(int members, double limit) {
    final intl.NumberFormat membersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String membersString = membersNumberFormat.format(members);
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$membersString/$limitString人';
  }

  @override
  String get confirmRemoveUser => 'このユーザーをリストから外しますか？';

  @override
  String get removeUser => '外す';

  @override
  String get confirmDeleteList => 'このリストを削除しますか？';

  @override
  String get homeOnly => 'ホームのみ';

  @override
  String get followersOnly => 'フォロワーのみ';

  @override
  String get originCombined => 'すべて';

  @override
  String get followerAscendingOrder => 'フォロワーが少ない順';

  @override
  String get followerDescendingOrder => 'フォロワーが多い順';

  @override
  String get createdAtAscendingOrder => '古い順';

  @override
  String get createdAtDescendingOrder => '新しい順';

  @override
  String get updatedAtAscendingOrder => '更新されていない順';

  @override
  String get updatedAtDescendingOrder => '更新された順';

  @override
  String get unsupportedFile => '対応していないファイルです';

  @override
  String unsupportedFileWithFilename(String filename) {
    return '$filenameは対応していないファイルです';
  }

  @override
  String get failedFileSave => 'ファイルを保存できませんでした';

  @override
  String get loopPlayback => 'ループ再生';

  @override
  String get misskeyGames => 'Misskey Games';

  @override
  String get cookieCliker => 'Cookie Cliker';

  @override
  String get bubbleGame => 'Bubble Game';

  @override
  String get reversi => 'リバーシ';

  @override
  String get loading => '読み込み中...';

  @override
  String invitedReversi(String users) {
    return '\$1から招待されています';
  }

  @override
  String get nonInvitedReversi => '招待されていません';

  @override
  String get remoteServerWithoutLogin => '相手先のサーバー（ログインなし）';

  @override
  String get nothingHere => '表示できる内容はありません';

  @override
  String get cacheRefreshNow => 'いますぐキャッシュを更新';

  @override
  String get cacheManualUpdateCompleted => '情報を更新しました';

  @override
  String get deckMode => 'デッキモード';

  @override
  String get enableDeckMode => 'デッキモードにする';

  @override
  String get template => 'テンプレート';

  @override
  String get noteBackgroundColor => 'ノート背景色';

  @override
  String get profileName => '名前';

  @override
  String get profileBio => '自己紹介';

  @override
  String get profileUpload => 'アップロード';

  @override
  String get profileFromDrive => 'ドライブから';

  @override
  String get profileFieldName => '名前';

  @override
  String get profileFieldValue => '内容';

  @override
  String get profileAddField => '項目を追加';

  @override
  String get profileSetBirthday => '誕生日を選択';

  @override
  String get profileFollowedMessage => 'フォローされたときのメッセージ';

  @override
  String get chat => 'チャット';

  @override
  String get chatInvitation => '招待';

  @override
  String get chatOwnRooms => '作成したルーム';

  @override
  String get chatJoining => '参加中のルーム';

  @override
  String get chatNewChat => '新しいチャットを開始';

  @override
  String get chatIgnored => '無視しました';

  @override
  String get chatNoDescription => '説明はありません';

  @override
  String get chatJoin => '参加';

  @override
  String get chatIgnore => '無視';

  @override
  String get chatSearch => 'チャット検索';

  @override
  String get chatInvited => '招待しました';

  @override
  String get chatRoomName => '名前';

  @override
  String get chatRoomDescription => '説明';

  @override
  String get chatUpdate => '更新';

  @override
  String get chatDelete => '削除する';

  @override
  String get chatCreator => 'チャットルームの作成者';

  @override
  String get confirmChatLeave => 'このチャットルームから退出しますか？';

  @override
  String get chatLeave => 'チャットから退出';

  @override
  String get chatLeftRoom => 'チャットルームから退出しました';

  @override
  String get chatRetry => '再試行';

  @override
  String get chatCreate => '作成';

  @override
  String get chatReaction => 'リアクション';

  @override
  String get chatReport => '通報';

  @override
  String get chatAttachedFiles => '添付ファイル';

  @override
  String get chatDetailInfo => '詳細情報';

  @override
  String get chatSentAt => '送信日時';

  @override
  String get chatSenderId => '送信者ID';

  @override
  String get chatReactionCount => 'リアクション数';

  @override
  String get chatReactionList => 'リアクション一覧';

  @override
  String get chatUnknownUser => '不明なユーザー';

  @override
  String get chatNsfw => 'NSFW';

  @override
  String get chatUpdateCompleted => 'チャットを更新しました';

  @override
  String chatRoomInvitation(String roomName) {
    return 'チャットルーム「$roomName」に招待されました';
  }

  @override
  String get goToChat => 'チャットを開く';

  @override
  String get noSearchResults => '検索結果が見つかりませんでした';

  @override
  String get saveToDrafts => '下書きに保存しますか？';

  @override
  String get discard => '破棄する';

  @override
  String get drafts => '下書き';

  @override
  String get noDrafts => '下書きはありません';

  @override
  String get confirmDeleteDraft => 'この下書きを削除しますか？';

  @override
  String get emptyNote => '空のノート';

  @override
  String get poll => 'アンケート';

  @override
  String get continueEditing => '編集を続ける';

  @override
  String get saveAndClose => '保存して閉じる';

  @override
  String get discardAndReturn => '保存せずに戻る';
}

/// The translations for Japanese (`ja_OJ`).
class SJaOj extends SJa {
  SJaOj() : super('ja_OJ');

  @override
  String get editProfile => 'プロフィール編集';

  @override
  String get apply => '変更いたしますわ';

  @override
  String get done => 'よろしくてよ';

  @override
  String get serverRules => 'サーバーの定め';

  @override
  String get willDelete => '消し去りますわ';

  @override
  String get cancel => 'おやめしますわ';

  @override
  String get noneAction => 'なにもいたしませんわ';

  @override
  String get pleaseInput => 'お入れなさって';

  @override
  String get pleaseSelect => 'お選びになさって';

  @override
  String get antennaSourceUserHintText => 'ユーザーネームを改行で区切って指定いたしますわ';

  @override
  String get antennaSourceKeywordsHintText =>
      'スペースで区切った単語はAND条件で、改行で区切った行はOR条件で扱いますことよ';

  @override
  String get antennaSourceExcludeKeywordsHintText =>
      'スペースで区切った単語はAND条件で、改行で区切った行はOR条件で扱いますことよ';

  @override
  String get discriminateUpperLower => '大文字と小文字を区別いたしますわ';

  @override
  String get receiveReplies => 'リプライを受け取りましてよ';

  @override
  String get receiveOnlyFiles => 'ファイル付きのノートのみ受け取りましてよ';

  @override
  String get receiveLocal => 'ローカルのみを受け取りましてよ';

  @override
  String get receiveLocalAvailability => 'ローカルのみの指定はMisskey 2023.10.2以降で有効ですこと';

  @override
  String get confirmDeletingAntenna => 'アンテナを削除いたしますこと？';

  @override
  String channelJoinningCounts(int usersCount) {
    final intl.NumberFormat usersCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String usersCountString = usersCountNumberFormat.format(usersCount);

    return '$usersCountString人が参加なされてますわ';
  }

  @override
  String get willFavorite => 'お気に入りに入れますわ';

  @override
  String get willFollow => 'フォローいたしますわ';

  @override
  String get confirmDeleteClip => 'クリップを削除いたしますこと？';

  @override
  String get clipDescription => '説明（省略されてもよろしくてよ）';

  @override
  String get alreadyAddedClip => 'こちらのノートすでにクリップに追加されていますわ';

  @override
  String get deleteClip => 'クリップから削除しますわ';

  @override
  String reportAbuseOf(String userName) {
    return '$userName を通報いたしますわ';
  }

  @override
  String get closeTweet => 'ツイートを閉じますわ';

  @override
  String get closePlayer => 'プレイヤーを閉じますわ';

  @override
  String get doneCopy => 'コピーいたしましたわ';

  @override
  String mutedNotePlaceholder(String userName) {
    return '$userNameが何か申しておりましたわ';
  }

  @override
  String get showCw => 'ちょっとだけなか見てもよろしくて';

  @override
  String get confirmDeleteReaction => 'リアクション取り消しますの？';

  @override
  String get cancelReaction => '取り消しあそばせ';

  @override
  String get renotedBy => 'がリノートいたしましたわ';

  @override
  String get selfRenotedBy => 'がセルフリノートされましたわ';

  @override
  String get savedImage => '画像を保存いたしましたわ';

  @override
  String get confirmDeletedRecreate =>
      'ノートを削除して作りなおすのかしら？ついたリアクションやRenote、返信は戻りませんわよ？';

  @override
  String get confirmDelete => 'ほんとうに削除してもよろしくて？';

  @override
  String get doDeleting => '消しましてよ';

  @override
  String confirmPoll(String choiced) {
    return '$choicedに投票いたしまして？';
  }

  @override
  String get renoted => 'リノートいたしましたわ';

  @override
  String get otherComplementReactions => '他を見繕いましてよ';

  @override
  String get openAsOtherAccount => '開くアカウントを選びなさって';

  @override
  String get pickColor => '色を選びなさって';

  @override
  String get decideColor => 'これにいたしますわ';

  @override
  String get replyNotePlaceholder => '何と送りますの？';

  @override
  String get defaultNotePlaceholder => 'ごきげんよう';

  @override
  String followedNotification(String userName) {
    return '$userNameからフォローされましてよ';
  }

  @override
  String followRequestAcceptedNotification(String userName) {
    return '$userNameがフォローしてもよくってよとお聞きいたしましたわ';
  }

  @override
  String receiveFollowRequestNotification(String userName) {
    return '$userNameがフォローさせてほしそういたしておりますわ';
  }

  @override
  String get achievementEarnedNotification => '実績を解除いたしましてよ';

  @override
  String get testNotification => 'テストですわよ';

  @override
  String get renotedUsersInNotification => 'リノートされた方';

  @override
  String get reactionUsersInNotification => 'リアクションされた人';

  @override
  String get finishedVotedNotification => '投票結果が出たそうですわよ';

  @override
  String get scheduledNotePostedNotification => '予約投稿がノートされましてよ';

  @override
  String get scheduledNotePostFailedNotification => '予約投稿が失敗したそうですわ';

  @override
  String renoteAndReactionsNotification(
    String? reactionUser,
    String? renotedUser,
  ) {
    return '$reactionUserらがリアクションを、$renotedUserらがリノートをされましたのよ';
  }

  @override
  String renoteNotification(String? renoteUser) {
    return '$renoteUserらがリノートされましてよ';
  }

  @override
  String reactionNotification(String? reactionUser) {
    return '$reactionUserらがリアクションされましてよ';
  }

  @override
  String notedNotification(String notedUser) {
    return '$notedUserらがノートいたしましてよ';
  }

  @override
  String roleAssignedNotification(String role) {
    return 'ロール「$role」に入れられましてよ';
  }

  @override
  String get appNotification => 'なにかしらのアプリからの通知のようでして';

  @override
  String get someoneLogined => 'ログインされたようですわ';

  @override
  String get unknownNotification => '存じ上げない種類の通知ですの';

  @override
  String get createTokenNotification => 'アクセストークンが作成されましたの';

  @override
  String get chatRoomInvitationReceivedNotification => 'チャットルームにお招きいただきましたの';

  @override
  String get cancelEmojiChoosing => 'やめておきますわ';

  @override
  String get doneEmojiChoosing => '使いますわ';

  @override
  String get confirmSavingPhoto => '保存いたしますこと？';

  @override
  String get doneEditingPhoto => '保存する';

  @override
  String get continueEditingPhoto => 'もうしばらく続けますわ';

  @override
  String get disabledUsingSensitiveCustomEmoji => 'ここではセンシティブなカスタム絵文字を使えないのでして';

  @override
  String get pageWrittenBy => 'このページを書きなさった方';

  @override
  String get unsupportedPage => 'DMSKY Clientが対応してないページのようですわ　ブラウザをお使いになさって';

  @override
  String get canNotFavoriteMyPage => '自分のページにいいねはできないのですわ';

  @override
  String get announcementsForYou => 'あなたさま宛';

  @override
  String confirmAnnouncementsRead(Object title) {
    return '「$title」の内容をお読みになさったこと？';
  }

  @override
  String get readAnnouncement => '読みましたわ';

  @override
  String get didNotReadAnnouncement => 'まだですわ';

  @override
  String get thrownError => 'なにか様子がおかしいですわね…';

  @override
  String get exportedFileNotFound => 'ここにDMSKY Clientの設定ファイル見つかりませんでしたわよ';

  @override
  String get importCompleted => 'インポート終わりましたわ';

  @override
  String get confirmOverwrite => 'ここにもうあるようですけれど……上書きいたしますの？';

  @override
  String get exportCompleted => 'エクスポート終わりましたわ';

  @override
  String get pleaseInputSomething => 'なにか入れてくださいまし？';

  @override
  String get pleaseAddVoteChoice => '投票の選択肢を2つ以上入れてくださいまし？';

  @override
  String get pleaseSpecifyExpirationDate => '投票がいつまでか入れてくださいまし？';

  @override
  String get pleaseSpecifyExpirationDuration => '投票期間を入れてくださいまし？';

  @override
  String get cannotMentionToRemoteInLocalOnlyNote =>
      '連合切られているのに他のサーバーの人がメンションに含まれているようですわ';

  @override
  String cannotPublicReplyToPrivateNote(String visibility) {
    return 'リプライが$visibilityのようでして……パブリックにはできませんこと';
  }

  @override
  String get unexpectedSensitive => '上げようとしたファイルがサーバーから、センシティブと思われたようですわね';

  @override
  String get staySensitive => 'センシティブのままにしますわ';

  @override
  String get cacheSizeError => '取得に失敗しましたわ';

  @override
  String get clearCache => 'キャッシュとお別れいたしますわ';

  @override
  String confirmUnblockUser(String userName) {
    return '$userNameのブロックを解除してもよろしくて？';
  }

  @override
  String confirmUnmuteUser(String userName) {
    return '$userNameのミュートを解除してもよろしくて？';
  }

  @override
  String get memoDescription => 'メモしたいことをお書きくださいまし';

  @override
  String get confirmCreateBlock => 'ブロックなさりますの？';

  @override
  String get confirmUnfollow => 'フォロー解除なさりますの？';

  @override
  String get unsupportedFile => '対応してないファイルのようですわ';

  @override
  String unsupportedFileWithFilename(String filename) {
    return '$filenameは対応してないファイルのようですわ';
  }

  @override
  String get failedFileSave => 'ファイルの保存に失敗したようですわね…';

  @override
  String invitedReversi(String users) {
    return '$usersから招待されているようですわ';
  }

  @override
  String get nonInvitedReversi => '招待されていないようですわね…';

  @override
  String get nothingHere => 'ここには何もありませんわ';

  @override
  String get cacheManualUpdateCompleted => '情報の取得が完了しましたわ';

  @override
  String get noteBackgroundColor => 'ノート背景色';

  @override
  String get profileName => 'お名前';

  @override
  String get profileBio => '自己紹介';

  @override
  String get profileUpload => 'アップロード';

  @override
  String get profileFromDrive => 'ドライブから';

  @override
  String get profileFieldName => '名前';

  @override
  String get profileFieldValue => '内容';

  @override
  String get profileAddField => '項目を追加';

  @override
  String get profileFollowedMessage => 'フォローされたときのメッセージ';

  @override
  String get chatCreator => 'チャットを立てた方';

  @override
  String get confirmChatLeave => '本当にこのチャットから退出いたしてもよろしくて？';

  @override
  String get chatUpdateCompleted => '更新できたようですわ';

  @override
  String chatRoomInvitation(String roomName) {
    return 'チャットルーム【$roomName】にお招きいただきましたの';
  }

  @override
  String get goToChat => '参りましょう';

  @override
  String get noSearchResults => '検索結果が見つかりませんでしたわ';

  @override
  String get saveToDrafts => '下書きに保存いたしますか？';

  @override
  String get discard => '破棄';

  @override
  String get drafts => '下書き';

  @override
  String get noDrafts => '下書きがございませんわ';

  @override
  String get confirmDeleteDraft => 'この下書きを削除いたしますか？';

  @override
  String get emptyNote => '空のノートですわ';

  @override
  String get continueEditing => 'もう少し編集を続けますわ';

  @override
  String get saveAndClose => '保存して閉じますわ';

  @override
  String get discardAndReturn => '保存せずに戻りますわ';
}
