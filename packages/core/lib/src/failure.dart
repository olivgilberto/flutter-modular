/// Base de todo erro sobre o qual o usuário pode agir. Cada módulo declara
/// a sua família selada sobre ela (capítulo 9).
abstract interface class Failure implements Exception {}
