/// Quem é o dono dos dados que os módulos guardam no aparelho (capítulo
/// 32). Só o id opaco do usuário, nunca nome ou e-mail: é o mínimo para
/// reconhecer outra pessoa entrando, e sai junto com os dados que protege.
///
/// Sobrevive a um reinício do app, ao contrário da memória do caso de uso:
/// uma sessão que expirou com alterações não enviadas deixa os dados no
/// aparelho, e o próximo login precisa saber de quem eles são.
abstract interface class DataOwnerRepository {
  /// `null` quando não há dados de ninguém no aparelho.
  Future<String?> currentOwner();

  Future<void> saveOwner(String userId);

  /// Chamado só depois que a limpeza dos dados terminou.
  Future<void> clearOwner();
}
