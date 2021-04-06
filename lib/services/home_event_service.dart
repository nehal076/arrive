import 'package:at_contacts_group_flutter/widgets/custom_toast.dart';
import 'package:atsign_location_app/plugins/at_events_flutter/models/event_notification.dart';
import 'package:atsign_location_app/plugins/at_location_flutter/at_location_flutter_plugin.dart';
import 'package:atsign_location_app/plugins/at_location_flutter/location_modal/location_notification.dart';
import 'package:atsign_location_app/plugins/at_location_flutter/service/send_location_notification.dart';
import 'package:atsign_location_app/common_components/provider_callback.dart';

import 'package:atsign_location_app/services/backend_service.dart';
import 'package:atsign_location_app/services/location_notification_listener.dart';
import 'package:atsign_location_app/services/location_sharing_service.dart';
import 'package:atsign_location_app/services/nav_service.dart';
import 'package:atsign_location_app/services/request_location_service.dart';
import 'package:atsign_location_app/view_models/hybrid_provider.dart';
import 'package:flutter/material.dart';
import 'package:atsign_location_app/view_models/event_provider.dart';
import 'package:atsign_location_app/plugins/at_events_flutter/models/hybrid_notifiation_model.dart';
import 'package:provider/provider.dart';

class HomeEventService {
  HomeEventService._();
  static HomeEventService _instance = HomeEventService._();
  factory HomeEventService() => _instance;

  List<HybridNotificationModel> allEvents = [];
  setAllEventsList(List<HybridNotificationModel> events) {
    allEvents = events;
  }

  get getAllEvents => allEvents;

  onLocationModelTap(
      LocationNotificationModel locationNotificationModel, bool haveResponded) {
    String currentAtsign = BackendService.getInstance()
        .atClientServiceInstance
        .atClient
        .currentAtSign;

    if (locationNotificationModel.key.contains('sharelocation'))
      locationNotificationModel.atsignCreator != currentAtsign
          // ignore: unnecessary_statements
          ? (locationNotificationModel.isAccepted
              ? navigatorPushToMap(locationNotificationModel)
              : (haveResponded
                  ? null
                  : BackendService.getInstance().showMyDialog(
                      locationNotificationModel.atsignCreator,
                      locationData: locationNotificationModel)))
          : navigatorPushToMap(locationNotificationModel);
    else if (locationNotificationModel.key.contains('requestlocation'))
      locationNotificationModel.atsignCreator == currentAtsign
          // ignore: unnecessary_statements
          ? (locationNotificationModel.isAccepted
              ? navigatorPushToMap(locationNotificationModel)
              : (haveResponded
                  ? null
                  : BackendService.getInstance().showMyDialog(
                      locationNotificationModel.atsignCreator,
                      locationData: locationNotificationModel)))
          // ignore: unnecessary_statements
          : (locationNotificationModel.isAccepted
              ? navigatorPushToMap(locationNotificationModel)
              : null);
  }

  onEventModelTap(EventNotificationModel eventNotificationModel,
      EventProvider provider, bool haveResponded) {
    if (isActionRequired(eventNotificationModel) &&
        !eventNotificationModel.isCancelled) {
      if (haveResponded) {
        return null;
      }
      return BackendService.getInstance().showMyDialog(
          eventNotificationModel.atsignCreator,
          eventData: eventNotificationModel);
    }

    eventNotificationModel.isUpdate = true;

    Navigator.push(
      NavService.navKey.currentContext,
      MaterialPageRoute(
        builder: (context) => AtLocationFlutterPlugin(
            BackendService.getInstance().atClientServiceInstance.atClient,
            allUsersList: LocationNotificationListener().allUsersList,
            onEventCancel: () async {
          await provider.cancelEvent(eventNotificationModel);
        }, onEventExit: (
                {bool isExited,
                bool isSharing,
                ATKEY_TYPE_ENUM keyType,
                EventNotificationModel eventData}) async {
          bool isNullSent = false;
          var result = await provider.actionOnEvent(
            eventData != null ? eventData : eventNotificationModel,
            keyType,
            isExited: isExited,
            isSharing: isSharing,
          );

          bool isAdmin = BackendService.getInstance()
                      .atClientServiceInstance
                      .atClient
                      .currentAtSign ==
                  eventNotificationModel.atsignCreator
              ? true
              : false;
          LocationNotificationModel locationNotificationModel =
              LocationNotificationModel()
                ..key = eventNotificationModel.key
                ..receiver = isAdmin
                    ? eventNotificationModel.group.members.elementAt(0).atSign
                    : eventNotificationModel.atsignCreator
                ..atsignCreator = !isAdmin
                    ? eventNotificationModel.group.members.elementAt(0).atSign
                    : eventNotificationModel.atsignCreator;
          if (isSharing != null) {
            if (!isSharing && result) {
              Provider.of<HybridProvider>(NavService.navKey.currentContext,
                      listen: false)
                  .removeLocationSharing(locationNotificationModel.key);

              isNullSent = await SendLocationNotification()
                  .sendNull(locationNotificationModel);
            }
          }
          if ((isExited != null) && (isExited && result)) {
            Provider.of<HybridProvider>(NavService.navKey.currentContext,
                    listen: false)
                .removeLocationSharing(locationNotificationModel.key);

            isNullSent = await SendLocationNotification()
                .sendNull(locationNotificationModel);
          }

          return result;
        }, onEventUpdate: (EventNotificationModel eventData) {
          provider.mapUpdatedEventDataToWidget(eventData);
        }, eventListenerKeyword: eventNotificationModel),
      ),
    );
  }

  navigatorPushToMap(LocationNotificationModel locationNotificationModel) {
    Navigator.push(
      NavService.navKey.currentContext,
      MaterialPageRoute(
        builder: (context) => AtLocationFlutterPlugin(
            BackendService.getInstance().atClientServiceInstance.atClient,
            allUsersList: LocationNotificationListener().allUsersList,
            userListenerKeyword: locationNotificationModel,
            onShareToggle: locationNotificationModel.key
                    .contains("sharelocation")
                ? LocationSharingService().updateWithShareLocationAcknowledge
                : RequestLocationService().requestLocationAcknowledgment,
            onRequest: locationNotificationModel.atsignCreator ==
                    BackendService.getInstance()
                        .atClientServiceInstance
                        .atClient
                        .currentAtSign
                ? () async {
                    var result = await RequestLocationService()
                        .sendRequestLocationEvent(
                            locationNotificationModel.receiver);
                    if (result[0] == true) {
                      CustomToast().show('Request Location sent', context);
                      providerCallback<HybridProvider>(
                          NavService.navKey.currentContext,
                          task: (provider) => provider.addNewEvent(
                              BackendService.getInstance().convertEventToHybrid(
                                  NotificationType.Location,
                                  locationNotificationModel: result[1])),
                          taskName: (provider) => provider.HYBRID_ADD_EVENT,
                          showLoader: false,
                          onSuccess: (provider) {});
                    } else {
                      CustomToast()
                          .show('Something went wrong ,try again !', context);
                    }
                  }
                : null,
            onRemove: locationNotificationModel.key.contains("sharelocation")
                ? (locationNotificationModel) async {
                    return await LocationSharingService()
                        .removePerson(locationNotificationModel);
                  }
                : (locationNotificationModel) async {
                    return await RequestLocationService()
                        .removePerson(locationNotificationModel);
                  }),
      ),
    );
  }
}

bool isActionRequired(EventNotificationModel event) {
  if (event.isCancelled) return true;

  bool isRequired = true;
  String currentAtsign = BackendService.getInstance()
      .atClientServiceInstance
      .atClient
      .currentAtSign;

  if (event.group.members.length < 1) return true;

  event.group.members.forEach((member) {
    if (member.atSign[0] != '@') member.atSign = '@' + member.atSign;
    if (currentAtsign[0] != '@') currentAtsign = '@' + currentAtsign;

    if ((member.tags['isAccepted'] != null &&
            member.tags['isAccepted'] == true) &&
        member.tags['isExited'] == false &&
        member.atSign.toLowerCase() == currentAtsign.toLowerCase()) {
      isRequired = false;
    }
  });

  if (event.atsignCreator == currentAtsign) isRequired = false;

  return isRequired;
}

String getActionString(EventNotificationModel event) {
  if (event.isCancelled) return 'Cancelled';
  String label = 'Action required';
  String currentAtsign = BackendService.getInstance()
      .atClientServiceInstance
      .atClient
      .currentAtSign;

  if (event.group.members.length < 1) return '';

  event.group.members.forEach((member) {
    if (member.atSign[0] != '@') member.atSign = '@' + member.atSign;
    if (currentAtsign[0] != '@') currentAtsign = '@' + currentAtsign;

    if (member.tags['isExited'] != null &&
        member.tags['isExited'] == true &&
        member.atSign.toLowerCase() == currentAtsign.toLowerCase()) {
      label = 'Request declined';
    } else if (member.tags['isExited'] != null &&
        member.tags['isExited'] == false &&
        member.tags['isAccepted'] != null &&
        member.tags['isAccepted'] == false &&
        member.atSign.toLowerCase() == currentAtsign.toLowerCase()) {
      label = 'Pending request';
    }
  });

  return label;
}

getSubTitle(HybridNotificationModel hybridNotificationModel) {
  DateTime to;
  String time;
  if (hybridNotificationModel.notificationType == NotificationType.Event) {
    return hybridNotificationModel.eventNotificationModel.event != null
        ? hybridNotificationModel.eventNotificationModel.event.date != null
            ? 'Event on ${dateToString(hybridNotificationModel.eventNotificationModel.event.date)}'
            : ''
        : '';
  } else if (hybridNotificationModel.notificationType ==
      NotificationType.Location) {
    to = hybridNotificationModel.locationNotificationModel.to;
    if (to != null)
      time =
          'until ${timeOfDayToString(hybridNotificationModel.locationNotificationModel.to)} today';
    else
      time = '';
    if (hybridNotificationModel.locationNotificationModel.key
        .contains('sharelocation')) {
      return hybridNotificationModel.locationNotificationModel.atsignCreator ==
              BackendService.getInstance()
                  .atClientServiceInstance
                  .atClient
                  .currentAtSign
          ? 'Can see my location $time'
          : 'Can see their location $time';
    } else {
      return hybridNotificationModel.locationNotificationModel.isAccepted
          ? (hybridNotificationModel.locationNotificationModel.atsignCreator ==
                  BackendService.getInstance()
                      .atClientServiceInstance
                      .atClient
                      .currentAtSign
              ? 'Sharing my location $time'
              : 'Sharing their location $time')
          : (hybridNotificationModel.locationNotificationModel.atsignCreator ==
                  BackendService.getInstance()
                      .atClientServiceInstance
                      .atClient
                      .currentAtSign
              ? 'Request Location received'
              : 'Request Location sent');
    }
  }
}

getSemiTitle(HybridNotificationModel hybridNotificationModel) {
  if (hybridNotificationModel.notificationType == NotificationType.Event) {
    return hybridNotificationModel.eventNotificationModel.group != null
        ? (isActionRequired(hybridNotificationModel.eventNotificationModel))
            ? getActionString(hybridNotificationModel.eventNotificationModel)
            : null
        : 'Action required';
  } else if (hybridNotificationModel.notificationType ==
      NotificationType.Location) {
    if (hybridNotificationModel.locationNotificationModel.key
        .contains('sharelocation'))
      return hybridNotificationModel.locationNotificationModel.atsignCreator !=
              BackendService.getInstance()
                  .atClientServiceInstance
                  .atClient
                  .currentAtSign
          ? (hybridNotificationModel.locationNotificationModel.isAccepted
              ? null
              : hybridNotificationModel.locationNotificationModel.isExited
                  ? 'Received Share location rejected'
                  : (hybridNotificationModel.haveResponded
                      ? 'Pending request'
                      : 'Action required'))
          : (hybridNotificationModel.locationNotificationModel.isAccepted
              ? null
              : hybridNotificationModel.locationNotificationModel.isExited
                  ? 'Sent Share location rejected'
                  : 'Awaiting response');
    else
      return hybridNotificationModel.locationNotificationModel.atsignCreator ==
              BackendService.getInstance()
                  .atClientServiceInstance
                  .atClient
                  .currentAtSign
          ? (!hybridNotificationModel.locationNotificationModel.isExited
              ? (hybridNotificationModel.locationNotificationModel.isAccepted
                  ? null
                  : (hybridNotificationModel.haveResponded
                      ? 'Pending request'
                      : 'Action required'))
              : 'Request rejected')
          : (!hybridNotificationModel.locationNotificationModel.isExited
              ? (hybridNotificationModel.locationNotificationModel.isAccepted
                  ? null
                  : 'Awaiting response')
              : 'Request rejected');
  }
}

getTitle(HybridNotificationModel hybridNotificationModel) {
  if (hybridNotificationModel.notificationType == NotificationType.Event) {
    return 'Event - ' + hybridNotificationModel.eventNotificationModel.title;
  } else if (hybridNotificationModel.notificationType ==
      NotificationType.Location) {
    return hybridNotificationModel.locationNotificationModel.atsignCreator ==
            BackendService.getInstance()
                .atClientServiceInstance
                .atClient
                .currentAtSign
        ? hybridNotificationModel.locationNotificationModel.receiver
        : hybridNotificationModel.locationNotificationModel.atsignCreator;
  }
}

bool calculateShowRetry(HybridNotificationModel hybridNotificationModel) {
  if (hybridNotificationModel.notificationType == NotificationType.Event) {
    if ((hybridNotificationModel.eventNotificationModel.group != null) &&
        (isActionRequired(hybridNotificationModel.eventNotificationModel)) &&
        (hybridNotificationModel.haveResponded)) {
      if (getActionString(hybridNotificationModel.eventNotificationModel) ==
          'Pending request') return true;
      return false;
    }
    return false;
  } else {
    if (hybridNotificationModel.locationNotificationModel.key
        .contains('sharelocation')) {
      if ((hybridNotificationModel.locationNotificationModel.atsignCreator !=
              BackendService.getInstance()
                  .atClientServiceInstance
                  .atClient
                  .currentAtSign) &&
          (!hybridNotificationModel.locationNotificationModel.isAccepted) &&
          (!hybridNotificationModel.locationNotificationModel.isExited) &&
          (hybridNotificationModel.haveResponded)) return true;

      return false;
    } else {
      if ((hybridNotificationModel.locationNotificationModel.atsignCreator ==
              BackendService.getInstance()
                  .atClientServiceInstance
                  .atClient
                  .currentAtSign) &&
          (!hybridNotificationModel.locationNotificationModel.isAccepted) &&
          (!hybridNotificationModel.locationNotificationModel.isExited) &&
          (hybridNotificationModel.haveResponded)) return true;

      return false;
    }
  }
}
