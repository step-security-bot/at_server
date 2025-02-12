import 'dart:async';
import 'dart:io';

import 'package:at_commons/at_commons.dart';
import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';
import 'package:test/test.dart';
import 'package:hive/hive.dart';

void main() async {
  var storageDir = '${Directory.current.path}/test/hive';

  group('A group of commit log test', () {
    setUp(() async => await setUpFunc(storageDir));
    test('test single insert', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var hiveKey =
          await commitLogInstance!.commit('location@alice', CommitOp.UPDATE);
      var committedEntry = await (commitLogInstance.getEntry(hiveKey));
      expect(committedEntry?.key, hiveKey);
      expect(committedEntry?.atKey, 'location@alice');
      expect(committedEntry?.operation, CommitOp.UPDATE);
      commitLogInstance = null;
    });
    test('test multiple insert', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('location@alice', CommitOp.DELETE);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 2);
    });

    test('test get entry ', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var key_1 =
          await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      var committedEntry = await (commitLogInstance?.getEntry(key_1));
      expect(committedEntry?.atKey, 'location@alice');
      expect(committedEntry?.operation, CommitOp.UPDATE);
      expect(committedEntry?.opTime, isNotNull);
      expect(committedEntry?.commitId, isNotNull);
    });

    test('test entries since commit Id', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      var key_1 =
          await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);

      await commitLogInstance!.commit('phone@alice', CommitOp.UPDATE);
      var changes = await commitLogInstance.getChanges(key_1, '');
      expect(changes.length, 1);
      expect(changes[0].atKey, 'phone@alice');
    });

    test('test last sequence number called once', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 1);
    });

    test('test last sequence number called multiple times', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 1);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 1);
    });

    test(
        'test to verify commitId does not increment for public hidden keys with single _',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var commitId = await commitLogInstance?.commit(
          'public:_location@alice', CommitOp.UPDATE);
      expect(commitId, -1);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), -1);
    });

    test('test to verify commitId does not increment for privatekey', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var commitId = await commitLogInstance?.commit(
          'privatekey:testkey@alice', CommitOp.UPDATE);
      expect(commitId, -1);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), -1);
    });

    test('test to verify commitId increments for signing public key', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var commitId = await commitLogInstance?.commit(
          'public:signing_publickey@alice', CommitOp.UPDATE);
      expect(commitId, 0);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 0);
    });

    test('test to verify commitId increments for signing private key',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var commitId = await commitLogInstance?.commit(
          '@alice:signing_privatekey@alice', CommitOp.UPDATE);
      expect(commitId, 0);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 0);
    });

    test(
        'test to verify commitId does not increment for key starting with private:',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var commitId = await commitLogInstance?.commit(
          'private:testkey@alice', CommitOp.UPDATE);
      expect(commitId, -1);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), -1);
    });

    test(
        'test to verify commitId does increment for public hidden keys with multiple __',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var commitId = await commitLogInstance?.commit(
          'public:__location@alice', CommitOp.UPDATE);
      expect(commitId, 0);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 0);
    });
    tearDown(() async => await tearDownFunc());
  });

  group('A group of tests to verify lastSynced commit entry', () {
    setUp(() async => await setUpFunc(storageDir, enableCommitId: false));
    test(
        'test to verify the last synced entry returns entry with highest commit id',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('mobile@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('phone@alice', CommitOp.UPDATE);

      CommitEntry? commitEntry0 = await commitLogInstance?.getEntry(0);
      await commitLogInstance?.update(commitEntry0!, 1);
      CommitEntry? commitEntry1 = await commitLogInstance?.getEntry(1);
      await commitLogInstance?.update(commitEntry1!, 0);
      var lastSyncedEntry = await commitLogInstance?.lastSyncedEntry();
      expect(lastSyncedEntry!.commitId, 1);
      var lastSyncedCacheSize = commitLogInstance!.commitLogKeyStore
          .getLastSyncedEntryCacheMapValues()
          .length;
      expect(lastSyncedCacheSize, 1);
    });

    test('test to verify the last synced entry with regex', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location.buzz@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('mobile.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('phone.buzz@alice', CommitOp.UPDATE);

      CommitEntry? commitEntry0 = await commitLogInstance?.getEntry(0);
      await commitLogInstance?.update(commitEntry0!, 2);
      CommitEntry? commitEntry1 = await commitLogInstance?.getEntry(1);
      await commitLogInstance?.update(commitEntry1!, 1);
      CommitEntry? commitEntry2 = await commitLogInstance?.getEntry(2);
      await commitLogInstance?.update(commitEntry2!, 0);
      var lastSyncedEntry =
          await commitLogInstance?.lastSyncedEntryWithRegex('buzz');
      expect(lastSyncedEntry!.atKey!, 'location.buzz@alice');
      expect(lastSyncedEntry.commitId!, 2);
      lastSyncedEntry =
          await commitLogInstance?.lastSyncedEntryWithRegex('wavi');
      expect(lastSyncedEntry!.atKey!, 'mobile.wavi@alice');
      expect(lastSyncedEntry.commitId!, 1);
      var lastSyncedEntriesList = commitLogInstance!.commitLogKeyStore
          .getLastSyncedEntryCacheMapValues();
      expect(lastSyncedEntriesList.length, 2);
    });

    test(
        'Test to verify that null is returned when no values are present in local keystore',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var lastSyncedEntry = await commitLogInstance?.lastSyncedEntry();
      expect(lastSyncedEntry, null);
    });

    test(
        'Test to verify that null is returned when matches entry for regex is not found',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location.buzz@alice', CommitOp.UPDATE);
      CommitEntry? commitEntry0 = await commitLogInstance?.getEntry(0);
      await commitLogInstance?.update(commitEntry0!, 2);
      var lastSyncedEntry =
          await commitLogInstance?.lastSyncedEntryWithRegex('wavi');
      expect(lastSyncedEntry, null);
    });
    tearDown(() async => await tearDownFunc());
  });

  group('A group of commit log compaction tests', () {
    setUp(() async => await setUpFunc(storageDir));
    test('Test to verify compaction when single is modified ten times',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var compactionService =
          CommitLogCompactionService(commitLogInstance!.commitLogKeyStore);
      commitLogInstance.addEventListener(compactionService);
      for (int i = 0; i <= 50; i++) {
        await commitLogInstance.commit('location@alice', CommitOp.UPDATE);
      }

      var list = compactionService.getEntries('location@alice');
      expect(list?.getSize(), 1);
    });

    test('Test to verify compaction when two are modified ten times', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var compactionService =
          CommitLogCompactionService(commitLogInstance!.commitLogKeyStore);
      commitLogInstance.addEventListener(compactionService);
      for (int i = 0; i <= 50; i++) {
        await commitLogInstance.commit('location@alice', CommitOp.UPDATE);
        await commitLogInstance.commit('country@alice', CommitOp.UPDATE);
      }
      var locationList = compactionService.getEntries('location@alice');
      var countryList = compactionService.getEntries('country@alice');
      expect(locationList!.getSize(), 1);
      expect(countryList!.getSize(), 1);
    });

    test('A test to verify old commit entry is removed when a key is updated',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      for (int i = 0; i < 5; i++) {
        await commitLogInstance!.commit('location.wavi@alice', CommitOp.UPDATE);
      }
      Iterator iterator =
          commitLogInstance!.getEntries(-1, regex: 'location.wavi');
      iterator.moveNext();
      expect(iterator.current.value.commitId, 4);
      expect(iterator.current.value.atKey, 'location.wavi@alice');
      expect(iterator.current.value.operation, CommitOp.UPDATE);
    });

    test('A test to verify old commit entry is removed when a key is delete',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      await commitLogInstance!.commit('location.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance.commit('location.wavi@alice', CommitOp.DELETE);
      // Fetch the commit entry using the lastSyncedCommitEntry
      Iterator iterator =
          commitLogInstance.getEntries(-1, regex: 'location.wavi');
      iterator.moveNext();
      expect(iterator.current.value.commitId, 1);
      expect(iterator.current.value.atKey, 'location.wavi@alice');
      expect(iterator.current.value.operation, CommitOp.DELETE);
    });

    test(
        'A test to verify if size of commit log matches length of commit log cache map then commit log keystore is compacted',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      // Add 5 distinct keys
      await commitLogInstance!.commit('firstname.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance.commit('lastName.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance.commit('country.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance.commit('phone.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance.commit('location.wavi@alice', CommitOp.UPDATE);
      // Update the keys
      await commitLogInstance.commit(
          'location.wavi@alice', CommitOp.UPDATE_ALL);
      await commitLogInstance.commit(
          'lastName.wavi@alice', CommitOp.UPDATE_ALL);
      await commitLogInstance.commit('firstname.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance.commit('country.wavi@alice', CommitOp.UPDATE);
      // Add a new key which is NOT in commit log keystore
      await commitLogInstance.commit('city.wavi@alice', CommitOp.UPDATE);
      // Delete the existing key
      await commitLogInstance.commit('location.wavi@alice', CommitOp.DELETE);
      // Verify size of commit log keystore and commit log cache map are equal
      expect(commitLogInstance.commitLogKeyStore.getBox().keys.length,
          commitLogInstance.commitLogKeyStore.commitEntriesList().length);
      // Get all entries from the commit log keystore.
      Iterator itr = commitLogInstance.commitLogKeyStore.getBox().keys.iterator;
      itr.moveNext();
      CommitEntry commitEntry =
          (commitLogInstance.commitLogKeyStore.getBox() as Box)
              .get(itr.current);
      expect(commitEntry.atKey, 'phone.wavi@alice');
      expect(commitEntry.commitId, 3);
      expect(commitEntry.operation, CommitOp.UPDATE);
      itr.moveNext();
      commitEntry = (commitLogInstance.commitLogKeyStore.getBox() as Box)
          .get(itr.current);
      expect(commitEntry.atKey, 'lastName.wavi@alice');
      expect(commitEntry.commitId, 6);
      expect(commitEntry.operation, CommitOp.UPDATE_ALL);
      itr.moveNext();
      commitEntry = (commitLogInstance.commitLogKeyStore.getBox() as Box)
          .get(itr.current);
      expect(commitEntry.atKey, 'firstname.wavi@alice');
      expect(commitEntry.commitId, 7);
      expect(commitEntry.operation, CommitOp.UPDATE);
      itr.moveNext();
      commitEntry = (commitLogInstance.commitLogKeyStore.getBox() as Box)
          .get(itr.current);
      expect(commitEntry.atKey, 'country.wavi@alice');
      expect(commitEntry.commitId, 8);
      expect(commitEntry.operation, CommitOp.UPDATE);
      itr.moveNext();
      commitEntry = (commitLogInstance.commitLogKeyStore.getBox() as Box)
          .get(itr.current);
      expect(commitEntry.atKey, 'city.wavi@alice');
      expect(commitEntry.commitId, 9);
      expect(commitEntry.operation, CommitOp.UPDATE);
      itr.moveNext();
      commitEntry = (commitLogInstance.commitLogKeyStore.getBox() as Box)
          .get(itr.current);
      expect(commitEntry.atKey, 'location.wavi@alice');
      expect(commitEntry.commitId, 10);
      expect(commitEntry.operation, CommitOp.DELETE);
      // To ensure there are no more keys in iterator.
      expect(itr.moveNext(), false);
    });
    tearDown(() async => await tearDownFunc());
  });

  group('A group of tests to verify repair commit log', () {
    setUp(() async => await setUpFunc(storageDir, enableCommitId: false));
    test('A test to verify null commit id gets replaced with hive internal key',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      var commitLogMap = await commitLogInstance?.commitLogKeyStore.toMap();
      expect(commitLogMap?.values.first.commitId, null);
      await commitLogInstance?.commitLogKeyStore
          .repairNullCommitIDs(commitLogMap!);
      commitLogMap = await commitLogInstance?.commitLogKeyStore.toMap();
      expect(commitLogMap?.values.first.commitId, 0);
    });

    test(
        'A test to verify multiple null commit id gets replaced with hive internal key',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      // Inserting commitEntry with commitId 0
      await commitLogInstance!.commitLogKeyStore.getBox().add(
          CommitEntry('location@alice', CommitOp.UPDATE, DateTime.now())
            ..commitId = 0);
      // Inserting commitEntry with null commitId
      await commitLogInstance.commitLogKeyStore
          .getBox()
          .add(CommitEntry('location@alice', CommitOp.UPDATE, DateTime.now()));
      // Inserting commitEntry with commitId 2
      await commitLogInstance.commitLogKeyStore.getBox().add(
          CommitEntry('phone@alice', CommitOp.UPDATE, DateTime.now())
            ..commitId = 2);
      // Inserting commitEntry with null commitId
      await commitLogInstance.commitLogKeyStore
          .getBox()
          .add(CommitEntry('mobile@alice', CommitOp.UPDATE, DateTime.now()));

      var commitLogMap = await commitLogInstance.commitLogKeyStore.toMap();
      await commitLogInstance.commitLogKeyStore
          .repairNullCommitIDs(commitLogMap);
      commitLogMap = await commitLogInstance.commitLogKeyStore.toMap();
      commitLogMap.forEach((key, value) {
        assert(value.commitId != null);
        expect(value.commitId, key);
      });

      // verify the commit id's return correct key's
      expect((await commitLogInstance.commitLogKeyStore.get(1))?.atKey,
          'location@alice');
      expect((await commitLogInstance.commitLogKeyStore.get(3))?.atKey,
          'mobile@alice');
    });
    tearDown(() async => await tearDownFunc());
  });

  group('A group of tests to verify commit log cache map', () {
    setUp(() async => await setUpFunc(storageDir, enableCommitId: true));
    test('test to verify the entries count in commit cache map after commit',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('mobile@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('phone@alice', CommitOp.UPDATE);

      Iterator? entriesIterator = commitLogInstance?.getEntries(-1);
      int commitLogCountBeforeDeletion = 0;
      if (entriesIterator != null) {
        while (entriesIterator.moveNext()) {
          commitLogCountBeforeDeletion++;
        }
      }
      expect(commitLogCountBeforeDeletion, 3);
    });
    test(
        'test to verify the entries count in commit cache map after removing from commit log',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      int? commitIdToRemove =
          await commitLogInstance?.commit('mobile@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('phone@alice', CommitOp.UPDATE);

      Iterator? entriesIterator = commitLogInstance?.getEntries(-1);
      int commitLogCountBeforeDeletion = 0;
      if (entriesIterator != null) {
        while (entriesIterator.moveNext()) {
          commitLogCountBeforeDeletion++;
        }
      }
      expect(commitLogCountBeforeDeletion, 3);
      await commitLogInstance?.commitLogKeyStore.remove(commitIdToRemove!);
      entriesIterator = commitLogInstance?.getEntries(-1);
      int commitLogCountAfterDeletion = 0;
      if (entriesIterator != null) {
        while (entriesIterator.moveNext()) {
          commitLogCountAfterDeletion++;
        }
      }
      expect(commitLogCountAfterDeletion, 2);
    });
    test('test to verify the whether correct entry is removed from cache',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      int? commitIdToRemove =
          await commitLogInstance?.commit('mobile@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit('phone@alice', CommitOp.UPDATE);

      await commitLogInstance?.commitLogKeyStore.remove(commitIdToRemove!);
      final commitEntry = await commitLogInstance?.getEntry(commitIdToRemove);
      expect(commitEntry, isNull);
    });
    test(
        'A test to verify only commit entries with null commitId are returned when enableCommitId is false',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var commitLogKeystore = commitLogInstance!.commitLogKeyStore;
      //setting enable commitId to false - to test client side functionality
      commitLogKeystore.enableCommitId = false;
      //loop to create 10 keys - even keys have commitId null - odd keys have commitId
      for (int i = 0; i < 10; i++) {
        if (i % 2 == 0) {
          await commitLogKeystore.getBox().add(CommitEntry(
              'test_key_false_$i', CommitOp.UPDATE, DateTime.now()));
        } else {
          await commitLogKeystore.getBox().add(
              CommitEntry('test_key_false_$i', CommitOp.UPDATE, DateTime.now())
                ..commitId = i);
        }
      }
      List<CommitEntry> changes =
          await commitLogInstance.commitLogKeyStore.getChanges(-1);
      //run loop and test all commit entries returned have commitId == null
      for (var element in changes) {
        expect(element.commitId, null);
      }
    });

    test(
        'A test to verify all commit entries are returned when enableCommitId is true',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var commitLogKeystore = commitLogInstance!.commitLogKeyStore;
      //loop to create 10 keys - even keys have commitId null - odd keys have commitId
      for (int i = 0; i < 10; i++) {
        if (i % 2 == 0) {
          await commitLogKeystore.getBox().add(
              CommitEntry('test_key_true_$i', CommitOp.UPDATE, DateTime.now()));
        } else {
          await commitLogKeystore.getBox().add(
              CommitEntry('test_key_true_$i', CommitOp.UPDATE, DateTime.now())
                ..commitId = i);
        }
      }
      List<CommitEntry> changes =
          await commitLogInstance.commitLogKeyStore.getChanges(-1);
      //run loop to ensure all commit entries have been returned; irrespective of commitId null or not
      for (int i = 0; i < 10; i++) {
        if (i % 2 == 0) {
          //while creation of commit entries, even keys have been set with commitId == null
          expect(changes[i].commitId, null);
        } else {
          //while creation of commit entries, even keys have been set with commitId equal to iteration count
          expect(changes[i].commitId, i);
        }
      }
    });

    test(
        'A test to verify entries in commit cache map are sorted by commit-id in ascending order',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      await commitLogInstance?.commit(
          '@alice:key1.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit(
          '@alice:key2.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit(
          '@alice:key3.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit(
          '@alice:key2.wavi@alice', CommitOp.DELETE);
      await commitLogInstance?.commit(
          '@alice:key1.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance!.commitLogKeyStore
          .repairCommitLogAndCreateCachedMap();
      Iterator<MapEntry<String, CommitEntry>> itr =
          commitLogInstance.getEntries(-1);
      itr.moveNext();
      expect(itr.current.key, '@alice:key3.wavi@alice');
      expect(itr.current.value.commitId, 2);
      expect(itr.current.value.operation, CommitOp.UPDATE);

      itr.moveNext();
      expect(itr.current.key, '@alice:key2.wavi@alice');
      expect(itr.current.value.commitId, 3);
      expect(itr.current.value.operation, CommitOp.DELETE);

      itr.moveNext();
      expect(itr.current.key, '@alice:key1.wavi@alice');
      expect(itr.current.value.commitId, 4);
      expect(itr.current.value.operation, CommitOp.UPDATE);
    });

    test(
        'A test to verify the order of keys and values in commit log cache map',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      await commitLogInstance?.commit(
          '@alice:key1.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit(
          '@alice:key2.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit(
          '@alice:key3.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance?.commit(
          '@alice:key2.wavi@alice', CommitOp.DELETE);
      await commitLogInstance?.commit(
          '@alice:key1.wavi@alice', CommitOp.UPDATE);
      await commitLogInstance!.commitLogKeyStore
          .repairCommitLogAndCreateCachedMap();

      List<MapEntry<String, CommitEntry>> commitEntriesList =
          commitLogInstance.commitLogKeyStore.commitEntriesList();
      expect(commitEntriesList[0].key, '@alice:key3.wavi@alice');
      expect(commitEntriesList[0].value.commitId, 2);

      expect(commitEntriesList[1].key, '@alice:key2.wavi@alice');
      expect(commitEntriesList[1].value.commitId, 3);

      expect(commitEntriesList[2].key, '@alice:key1.wavi@alice');
      expect(commitEntriesList[2].value.commitId, 4);
    });

    tearDown(() async => await tearDownFunc());
  });

  group('A group of tests to verify local key does not add to commit log', () {
    test('local key does not add to commit log', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      var commitId = await commitLogInstance?.commit(
          'local:phone.wavi@alice', CommitOp.UPDATE);
      expect(commitId, -1);
    });

    test(
        'Test to verify local created with static local method does not add to commit log',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      var atKey = AtKey.local('phone', '@alice', namespace: 'wavi').build();

      var commitId =
          await commitLogInstance?.commit(atKey.toString(), CommitOp.UPDATE);
      expect(commitId, -1);
    });

    test('Test to verify local created with AtKey does not add to commit log',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var atKey = AtKey()
        ..key = 'phone'
        ..sharedBy = '@alice'
        ..namespace = 'wavi'
        ..isLocal = true;
      var commitId =
          await commitLogInstance?.commit(atKey.toString(), CommitOp.UPDATE);
      expect(commitId, -1);
    });
  });
}

Future<SecondaryKeyStoreManager> setUpFunc(storageDir,
    {bool enableCommitId = true}) async {
  var commitLogInstance = await AtCommitLogManagerImpl.getInstance()
      .getCommitLog('@alice',
          commitLogPath: storageDir, enableCommitId: enableCommitId);
  var secondaryPersistenceStore = SecondaryPersistenceStoreFactory.getInstance()
      .getSecondaryPersistenceStore('@alice')!;
  var persistenceManager =
      secondaryPersistenceStore.getHivePersistenceManager()!;
  await persistenceManager.init(storageDir);
//  persistenceManager.scheduleKeyExpireTask(1); //commented this line for coverage test
  var hiveKeyStore = secondaryPersistenceStore.getSecondaryKeyStore()!;
  hiveKeyStore.commitLog = commitLogInstance;
  var keyStoreManager =
      secondaryPersistenceStore.getSecondaryKeyStoreManager()!;
  keyStoreManager.keyStore = hiveKeyStore;
  return keyStoreManager;
}

Future<void> tearDownFunc() async {
  await AtCommitLogManagerImpl.getInstance().close();
  var isExists = await Directory('test/hive/').exists();
  if (isExists) {
    Directory('test/hive').deleteSync(recursive: true);
  }
}
