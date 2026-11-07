import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// O cliente de rede de verdade: os sockets do dart:io, como o adaptador
/// padrão do Dio, com o tempo limite de conexão.
http.Client ioClient({required Duration connectionTimeout}) =>
    IOClient(HttpClient()..connectionTimeout = connectionTimeout);
