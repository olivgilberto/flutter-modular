import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/app_router.dart';

String? redirect(
  String location, {
  required bool languageChosen,
  bool authenticated = true,
}) => appRedirect(
  Uri.parse(location),
  languageChosen: languageChosen,
  authenticated: authenticated,
);

void main() {
  group('sem idioma escolhido', () {
    test('qualquer tela leva à escolha, levando o destino junto', () {
      expect(redirect('/', languageChosen: false), '/language?from=%2F');
      expect(
        redirect('/auth/login?next=1', languageChosen: false),
        '/language?from=%2Fauth%2Flogin%3Fnext%3D1',
      );
    });

    test('a própria tela de escolha não redireciona', () {
      expect(redirect('/language?from=%2F', languageChosen: false), isNull);
    });

    test('o idioma vem antes da sessão', () {
      expect(
        redirect('/', languageChosen: false, authenticated: false),
        '/language?from=%2F',
      );
    });
  });

  group('com idioma escolhido', () {
    test('a tela de escolha devolve ao destino original', () {
      expect(
        redirect(
          '/language?from=%2Fauth%2Flogin%3Fnext%3D1',
          languageChosen: true,
        ),
        '/auth/login?next=1',
      );
    });

    test('sem destino, ou com um destino externo, vai para a tela '
        'inicial', () {
      expect(redirect('/language', languageChosen: true), '/');
      expect(
        redirect(
          '/language?from=https%3A%2F%2Fexemplo.com',
          languageChosen: true,
        ),
        '/',
      );
      expect(
        redirect('/language?from=%2F%2Fexemplo.com', languageChosen: true),
        '/',
      );
    });

    test('com sessão, as outras telas seguem sem redirect', () {
      expect(redirect('/', languageChosen: true), isNull);
    });
  });

  group('sem sessão', () {
    String? signedOut(String location) =>
        redirect(location, languageChosen: true, authenticated: false);

    test('qualquer tela do app leva ao login, levando o destino junto', () {
      expect(signedOut('/'), '/auth/login?from=%2F');
      expect(signedOut('/tasks/42'), '/auth/login?from=%2Ftasks%2F42');
    });

    test('as telas do auth_module abrem', () {
      expect(signedOut('/auth/login'), isNull);
      expect(signedOut('/auth/register'), isNull);
      expect(signedOut('/auth/login?from=%2Ftasks%2F42'), isNull);
    });

    test('um caminho que só começa como o do módulo não escapa', () {
      expect(signedOut('/authors'), '/auth/login?from=%2Fauthors');
    });
  });

  group('com sessão', () {
    test('as telas de entrar levam ao destino original, ou ao início', () {
      expect(
        redirect('/auth/login?from=%2Ftasks%2F42', languageChosen: true),
        '/tasks/42',
      );
      expect(redirect('/auth/register', languageChosen: true), '/');
      expect(
        redirect(
          '/auth/login?from=https%3A%2F%2Fexemplo.com',
          languageChosen: true,
        ),
        '/',
      );
    });
  });
}
