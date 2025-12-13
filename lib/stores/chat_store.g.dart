// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChatStore on ChatStoreBase, Store {
  late final _$currentConversationAtom = Atom(
    name: 'ChatStoreBase.currentConversation',
    context: context,
  );

  @override
  Conversation? get currentConversation {
    _$currentConversationAtom.reportRead();
    return super.currentConversation;
  }

  @override
  set currentConversation(Conversation? value) {
    _$currentConversationAtom.reportWrite(value, super.currentConversation, () {
      super.currentConversation = value;
    });
  }

  late final _$messagesAtom = Atom(
    name: 'ChatStoreBase.messages',
    context: context,
  );

  @override
  ObservableList<Message> get messages {
    _$messagesAtom.reportRead();
    return super.messages;
  }

  @override
  set messages(ObservableList<Message> value) {
    _$messagesAtom.reportWrite(value, super.messages, () {
      super.messages = value;
    });
  }

  late final _$conversationsAtom = Atom(
    name: 'ChatStoreBase.conversations',
    context: context,
  );

  @override
  ObservableList<Conversation> get conversations {
    _$conversationsAtom.reportRead();
    return super.conversations;
  }

  @override
  set conversations(ObservableList<Conversation> value) {
    _$conversationsAtom.reportWrite(value, super.conversations, () {
      super.conversations = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: 'ChatStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isLoadingConversationsAtom = Atom(
    name: 'ChatStoreBase.isLoadingConversations',
    context: context,
  );

  @override
  bool get isLoadingConversations {
    _$isLoadingConversationsAtom.reportRead();
    return super.isLoadingConversations;
  }

  @override
  set isLoadingConversations(bool value) {
    _$isLoadingConversationsAtom.reportWrite(
      value,
      super.isLoadingConversations,
      () {
        super.isLoadingConversations = value;
      },
    );
  }

  late final _$errorAtom = Atom(name: 'ChatStoreBase.error', context: context);

  @override
  String? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(String? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$currentResponseAtom = Atom(
    name: 'ChatStoreBase.currentResponse',
    context: context,
  );

  @override
  String get currentResponse {
    _$currentResponseAtom.reportRead();
    return super.currentResponse;
  }

  @override
  set currentResponse(String value) {
    _$currentResponseAtom.reportWrite(value, super.currentResponse, () {
      super.currentResponse = value;
    });
  }

  late final _$selectedMaterialIdsAtom = Atom(
    name: 'ChatStoreBase.selectedMaterialIds',
    context: context,
  );

  @override
  List<int>? get selectedMaterialIds {
    _$selectedMaterialIdsAtom.reportRead();
    return super.selectedMaterialIds;
  }

  @override
  set selectedMaterialIds(List<int>? value) {
    _$selectedMaterialIdsAtom.reportWrite(value, super.selectedMaterialIds, () {
      super.selectedMaterialIds = value;
    });
  }

  late final _$startNewConversationAsyncAction = AsyncAction(
    'ChatStoreBase.startNewConversation',
    context: context,
  );

  @override
  Future<void> startNewConversation(String title, {int? materialId}) {
    return _$startNewConversationAsyncAction.run(
      () => super.startNewConversation(title, materialId: materialId),
    );
  }

  late final _$loadConversationAsyncAction = AsyncAction(
    'ChatStoreBase.loadConversation',
    context: context,
  );

  @override
  Future<void> loadConversation(int conversationId) {
    return _$loadConversationAsyncAction.run(
      () => super.loadConversation(conversationId),
    );
  }

  late final _$sendMessageAsyncAction = AsyncAction(
    'ChatStoreBase.sendMessage',
    context: context,
  );

  @override
  Future<void> sendMessage(String content) {
    return _$sendMessageAsyncAction.run(() => super.sendMessage(content));
  }

  late final _$sendImageMessageAsyncAction = AsyncAction(
    'ChatStoreBase.sendImageMessage',
    context: context,
  );

  @override
  Future<void> sendImageMessage(Uint8List imageBytes, String question) {
    return _$sendImageMessageAsyncAction.run(
      () => super.sendImageMessage(imageBytes, question),
    );
  }

  late final _$loadConversationsAsyncAction = AsyncAction(
    'ChatStoreBase.loadConversations',
    context: context,
  );

  @override
  Future<void> loadConversations() {
    return _$loadConversationsAsyncAction.run(() => super.loadConversations());
  }

  late final _$deleteConversationAsyncAction = AsyncAction(
    'ChatStoreBase.deleteConversation',
    context: context,
  );

  @override
  Future<void> deleteConversation(int conversationId) {
    return _$deleteConversationAsyncAction.run(
      () => super.deleteConversation(conversationId),
    );
  }

  late final _$regenerateLastResponseAsyncAction = AsyncAction(
    'ChatStoreBase.regenerateLastResponse',
    context: context,
  );

  @override
  Future<void> regenerateLastResponse() {
    return _$regenerateLastResponseAsyncAction.run(
      () => super.regenerateLastResponse(),
    );
  }

  late final _$ChatStoreBaseActionController = ActionController(
    name: 'ChatStoreBase',
    context: context,
  );

  @override
  void clearError() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void prepareNewChat() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.prepareNewChat',
    );
    try {
      return super.prepareNewChat();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearConversation() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.clearConversation',
    );
    try {
      return super.clearConversation();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setSelectedMaterials(List<int>? materialIds) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.setSelectedMaterials',
    );
    try {
      return super.setSelectedMaterials(materialIds);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
currentConversation: ${currentConversation},
messages: ${messages},
conversations: ${conversations},
isLoading: ${isLoading},
isLoadingConversations: ${isLoadingConversations},
error: ${error},
currentResponse: ${currentResponse},
selectedMaterialIds: ${selectedMaterialIds}
    ''';
  }
}
