import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/material.dart';
import '../../domain/entities/chunk.dart';
import '../../domain/entities/page.dart';
import '../../domain/entities/concept.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../objectbox.g.dart';

/// ObjectBox database manager
class ObjectBoxManager {
  late final Store store;
  late final Box<Material> materialBox;
  late final Box<Chunk> chunkBox;
  late final Box<Page> pageBox;
  late final Box<Concept> conceptBox;
  late final Box<Conversation> conversationBox;
  late final Box<Message> messageBox;

  ObjectBoxManager._create(this.store) {
    materialBox = Box<Material>(store);
    chunkBox = Box<Chunk>(store);
    pageBox = Box<Page>(store);
    conceptBox = Box<Concept>(store);
    conversationBox = Box<Conversation>(store);
    messageBox = Box<Message>(store);
  }

  /// Initialize ObjectBox
  static Future<ObjectBoxManager> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(directory: p.join(docsDir.path, 'edumate_objectbox'));
    return ObjectBoxManager._create(store);
  }

  /// Close the store
  void close() {
    store.close();
  }
}

