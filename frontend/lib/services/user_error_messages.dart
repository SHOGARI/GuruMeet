import 'api_client.dart';

String roomJoinErrorMessage(Object error) {
  if (error case ApiException(statusCode: 404)) {
    return 'ルームが見つかりません。招待URLかコードを確認してください。';
  }
  if (error case ApiException(statusCode: 409)) {
    return 'このルームは満員です。ホストに新しいルームの作成を依頼してください。';
  }
  if (error case ApiException(statusCode: 422)) {
    return '招待情報の形式が正しくありません。';
  }
  if (error case ApiException(statusCode: 429)) {
    return '参加の試行が多すぎます。少し時間をおいて再試行してください。';
  }
  return '通信に失敗しました。接続を確認して再試行してください。';
}

String roomCreateErrorMessage(Object error) {
  if (error case ApiException(statusCode: 400, message: final message)) {
    return message;
  }
  if (error case ApiException(statusCode: 502)) {
    return '店舗検索サービスに接続できませんでした。条件を変えるか、時間をおいて再試行してください。';
  }
  if (error case ApiException(statusCode: 504)) {
    return '店舗検索に時間がかかっています。エリアや予算を変えて再試行してください。';
  }
  return 'グループ作成に失敗しました。通信状態を確認して再試行してください。';
}

String roomDissolveErrorMessage(Object error) {
  if (error case ApiException(statusCode: 403)) {
    return 'このグループを解散できるのは作成者だけです。';
  }
  if (error case ApiException(statusCode: 404)) {
    return 'グループが見つかりません。すでに解散または期限切れの可能性があります。';
  }
  return 'グループの解散に失敗しました。通信状態を確認して再試行してください。';
}

String votingErrorMessage(Object error) {
  if (error case ApiException(statusCode: 400, message: final message)) {
    return message;
  }
  if (error case ApiException(statusCode: 403)) {
    return 'このルームの参加者として確認できません。招待URLから入り直してください。';
  }
  if (error case ApiException(statusCode: 404)) {
    return 'ルームが見つかりません。招待URLから入り直してください。';
  }
  if (error case ApiException(statusCode: 409)) {
    return '現在の状態では操作できません。画面を更新して再試行してください。';
  }
  return '通信に失敗しました。少し待って再試行してください。';
}
