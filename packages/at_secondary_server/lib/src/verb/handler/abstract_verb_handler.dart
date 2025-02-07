import 'dart:collection';
import 'dart:convert';
import 'package:at_commons/at_commons.dart';
import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';
import 'package:at_secondary/src/constants/enroll_constants.dart';
import 'package:at_secondary/src/enroll/enroll_datastore_value.dart';
import 'package:at_secondary/src/server/at_secondary_impl.dart';
import 'package:at_secondary/src/utils/handler_util.dart' as handler_util;
import 'package:at_secondary/src/verb/handler/sync_progressive_verb_handler.dart';
import 'package:at_secondary/src/verb/manager/response_handler_manager.dart';
import 'package:at_server_spec/at_server_spec.dart';
import 'package:at_server_spec/at_verb_spec.dart';
import 'package:at_utils/at_logger.dart';

final String paramFullCommandAsReceived = 'FullCommandAsReceived';

abstract class AbstractVerbHandler implements VerbHandler {
  final SecondaryKeyStore keyStore;

  late AtSignLogger logger;
  ResponseHandlerManager responseManager =
      DefaultResponseHandlerManager.getInstance();

  AbstractVerbHandler(this.keyStore) {
    logger = AtSignLogger(runtimeType.toString());
  }

  /// Parses a given command against a corresponding verb syntax
  /// @returns  Map containing  key(group name from syntax)-value from the command
  HashMap<String, String?> parse(String command) {
    try {
      return handler_util.getVerbParam(getVerb().syntax(), command);
    } on InvalidSyntaxException {
      throw InvalidSyntaxException('Invalid syntax. ${getVerb().usage()}');
    }
  }

  @override
  Future<void> process(String command, InboundConnection atConnection) async {
    var response = await processInternal(command, atConnection);
    var handler = responseManager.getResponseHandler(getVerb());
    await handler.process(atConnection, response);
  }

  Future<Response> processInternal(
      String command, InboundConnection atConnection) async {
    var response = Response();
    var atConnectionMetadata = atConnection.getMetaData();
    if (getVerb().requiresAuth() && !atConnectionMetadata.isAuthenticated) {
      throw UnAuthenticatedException('Command cannot be executed without auth');
    }
    try {
      // Parse the command
      var verbParams = parse(command);
      // TODO This is not ideal. Would be better to make it so that processVerb takes command as an argument also.
      verbParams[paramFullCommandAsReceived] = command;
      // Syntax is valid. Process the verb now.
      await processVerb(response, verbParams, atConnection);
      if (this is SyncProgressiveVerbHandler) {
        final verbHandler = this as SyncProgressiveVerbHandler;
        verbHandler.logResponse(response.data!);
      } else {
        logger.finer(
            'Verb : ${getVerb().name()}  Response: ${response.toString()}');
      }
      return response;
    } on Exception {
      rethrow;
    }
  }

  /// Return the instance of the current verb
  ///@return instance of [Verb]
  Verb getVerb();

  /// Process the given command using verbParam and requesting atConnection. Sets the data in response.
  ///@param response - response of the command
  ///@param verbParams - contains key-value mapping of groups names from verb syntax
  ///@param atConnection - Requesting connection
  Future<void> processVerb(Response response,
      HashMap<String, String?> verbParams, InboundConnection atConnection);

  Future<List<EnrollNamespace>> getEnrollmentNamespaces(
      String enrollmentId, String currentAtSign) async {
    final key = '$enrollmentId.$newEnrollmentKeyPattern.$enrollManageNamespace';
    EnrollDataStoreValue enrollDataStoreValue;
    try {
      enrollDataStoreValue =
          await getEnrollDataStoreValue('$key$currentAtSign');
    } on KeyNotFoundException {
      logger.warning('enrollment key not found in keystore $key');
      return [];
    }
    logger.finer('scan namespaces: ${enrollDataStoreValue.namespaces}');
    return enrollDataStoreValue.namespaces;
  }

  /// Fetch for an enrollment key in the keystore.
  /// If key is available returns [EnrollDataStoreValue],
  /// else throws [KeyNotFoundException]
  Future<EnrollDataStoreValue> getEnrollDataStoreValue(
      String enrollmentKey) async {
    try {
      AtData enrollData = await keyStore.get(enrollmentKey);
      EnrollDataStoreValue enrollDataStoreValue =
          EnrollDataStoreValue.fromJson(jsonDecode(enrollData.data!));
      return enrollDataStoreValue;
    } on KeyNotFoundException {
      logger.severe('$enrollmentKey does not exist in the keystore');
      rethrow;
    }
  }

  Future<bool> isAuthorized(
      String enrollApprovalId, String keyNamespace) async {
    EnrollDataStoreValue enrollDataStoreValue;
    final enrollmentKey =
        '$enrollApprovalId.$newEnrollmentKeyPattern.$enrollManageNamespace';
    try {
      enrollDataStoreValue = await getEnrollDataStoreValue(
          '$enrollmentKey${AtSecondaryServerImpl.getInstance().currentAtSign}');
    } on KeyNotFoundException {
      // When a key with enrollmentId is not found, atSign is not authorized to
      // perform enrollment actions. Return false.
      return false;
    }

    if (enrollDataStoreValue.approval?.state != EnrollStatus.approved.name) {
      return false;
    }

    final enrollNamespaces = await getEnrollmentNamespaces(
        enrollApprovalId, AtSecondaryServerImpl.getInstance().currentAtSign);

    logger.finer(
        'keyNamespace: $keyNamespace enrollNamespaces: $enrollNamespaces');
    for (EnrollNamespace namespace in enrollNamespaces) {
      if (namespace.name == keyNamespace) {
        logger.finer('current verb: ${getVerb()}');
        if (getVerb() is LocalLookup || getVerb() is Lookup) {
          if (namespace.access == 'r' || namespace.access == 'rw') {
            return true;
          }
        } else if (getVerb() is Update || getVerb() is Delete) {
          if (namespace.access == 'rw') {
            return true;
          }
        }
      }
    }
    return false;
  }
}
