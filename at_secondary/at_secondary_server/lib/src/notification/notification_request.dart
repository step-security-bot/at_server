import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';

abstract class NotificationRequest {
  late String request;

  NotificationRequest getRequest(AtNotification atNotification);
}

class NotificationRequestv1 implements NotificationRequest {
  @override
  late String request;

  @override
  NotificationRequest getRequest(
      AtNotification atNotification) {
    var notification = NotificationRequestv1();
    notification.request = '${atNotification.notification}';
    if (atNotification.atMetadata != null) {
      if (atNotification.atMetadata?.ttr != null) {
        notification.request =
            'ttr:${atNotification.atMetadata?.ttr}:ccd:${atNotification.atMetadata?.isCascade}:${notification.request}:${atNotification.atValue}';
      }
      if (atNotification.atMetadata?.ttb != null) {
        notification.request =
            'ttb:${atNotification.atMetadata?.ttb}:${notification.request}';
      }
      if (atNotification.atMetadata?.ttl != null) {
        notification.request =
            'ttl:${atNotification.atMetadata?.ttl}:${notification.request}';
      }
    }
    if (atNotification.ttl != null) {
      notification.request =
          'ttln:${atNotification.ttl}:${notification.request}';
    }
    notification.request =
        'notifier:${atNotification.notifier}:${notification.request}';
    notification.request =
        'messageType:${atNotification.messageType.toString().split('.').last}:${notification.request}';
    if (atNotification.opType != null) {
      notification.request =
          '${atNotification.opType.toString().split('.').last}:${notification.request}';
    }
    return notification;
  }
}

class NotificationRequestv2 extends NotificationRequestv1 {
  @override
  NotificationRequest getRequest(
      AtNotification atNotification) {
    var notificationRequest = NotificationRequestv2();
    notificationRequest.request = '${atNotification.notification}';
    atNotification.atMetadata?.toJson();
    if (atNotification.atMetadata != null) {
      if (atNotification.atMetadata?.pubKeyCS != null) {
        notificationRequest.request =
            'pubKeyCS:${atNotification.atMetadata?.pubKeyCS}:${notificationRequest.request}';
      }
      if (atNotification.atMetadata?.sharedKeyEnc != null) {
        notificationRequest.request =
            'sharedKeyEnc:${atNotification.atMetadata?.sharedKeyEnc}:${notificationRequest.request}';
      }
      if (atNotification.atMetadata?.ttr != null) {
        notificationRequest.request =
            'ttr:${atNotification.atMetadata?.ttr}:ccd:${atNotification.atMetadata?.isCascade}:${notificationRequest.request}:${atNotification.atValue}';
      }
      if (atNotification.atMetadata?.ttb != null) {
        notificationRequest.request =
            'ttb:${atNotification.atMetadata?.ttb}:${notificationRequest.request}';
      }
      if (atNotification.atMetadata?.ttl != null) {
        notificationRequest.request =
            'ttl:${atNotification.atMetadata?.ttl}:${notificationRequest.request}';
      }
    }
    if (atNotification.ttl != null) {
      notificationRequest.request =
          'ttln:${atNotification.ttl}:${notificationRequest.request}';
    }
    notificationRequest.request =
        'notifier:${atNotification.notifier}:${notificationRequest.request}';
    notificationRequest.request =
        'messageType:${atNotification.messageType.toString().split('.').last}:${notificationRequest.request}';
    if (atNotification.opType != null) {
      notificationRequest.request =
          '${atNotification.opType.toString().split('.').last}:${notificationRequest.request}';
    }
    notificationRequest.request = 'id:${atNotification.id}:${notificationRequest.request}';
    return notificationRequest;
  }
}
