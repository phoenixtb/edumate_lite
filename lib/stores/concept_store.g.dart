// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'concept_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ConceptStore on _ConceptStore, Store {
  Computed<int>? _$conceptCountComputed;

  @override
  int get conceptCount => (_$conceptCountComputed ??= Computed<int>(
    () => super.conceptCount,
    name: '_ConceptStore.conceptCount',
  )).value;

  late final _$conceptsAtom = Atom(
    name: '_ConceptStore.concepts',
    context: context,
  );

  @override
  ObservableList<Concept> get concepts {
    _$conceptsAtom.reportRead();
    return super.concepts;
  }

  @override
  set concepts(ObservableList<Concept> value) {
    _$conceptsAtom.reportWrite(value, super.concepts, () {
      super.concepts = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_ConceptStore.isLoading',
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

  late final _$errorAtom = Atom(name: '_ConceptStore.error', context: context);

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

  late final _$loadConceptsAsyncAction = AsyncAction(
    '_ConceptStore.loadConcepts',
    context: context,
  );

  @override
  Future<void> loadConcepts() {
    return _$loadConceptsAsyncAction.run(() => super.loadConcepts());
  }

  late final _$_ConceptStoreActionController = ActionController(
    name: '_ConceptStore',
    context: context,
  );

  @override
  Concept findOrCreate(String name, {String type = 'term', String? subject}) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.findOrCreate',
    );
    try {
      return super.findOrCreate(name, type: type, subject: subject);
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void addMaterialToConcept(int conceptId, int materialId, int chunkId) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.addMaterialToConcept',
    );
    try {
      return super.addMaterialToConcept(conceptId, materialId, chunkId);
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  List<Concept> getConceptsForMaterial(int materialId) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.getConceptsForMaterial',
    );
    try {
      return super.getConceptsForMaterial(materialId);
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  List<Concept> getTopConcepts({int limit = 20}) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.getTopConcepts',
    );
    try {
      return super.getTopConcepts(limit: limit);
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  List<Concept> searchConcepts(String query) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.searchConcepts',
    );
    try {
      return super.searchConcepts(query);
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  List<Concept> getRelatedConcepts(int conceptId, {int limit = 5}) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.getRelatedConcepts',
    );
    try {
      return super.getRelatedConcepts(conceptId, limit: limit);
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void deleteConcept(int conceptId) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.deleteConcept',
    );
    try {
      return super.deleteConcept(conceptId);
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearAll() {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.clearAll',
    );
    try {
      return super.clearAll();
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  List<Concept> extractAndStoreConcepts({
    required String content,
    required int materialId,
    required int chunkId,
    String? subject,
  }) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.extractAndStoreConcepts',
    );
    try {
      return super.extractAndStoreConcepts(
        content: content,
        materialId: materialId,
        chunkId: chunkId,
        subject: subject,
      );
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void linkConcepts(int conceptId1, int conceptId2) {
    final _$actionInfo = _$_ConceptStoreActionController.startAction(
      name: '_ConceptStore.linkConcepts',
    );
    try {
      return super.linkConcepts(conceptId1, conceptId2);
    } finally {
      _$_ConceptStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
concepts: ${concepts},
isLoading: ${isLoading},
error: ${error},
conceptCount: ${conceptCount}
    ''';
  }
}
