import 'package:ambot_app/models/chat_message.dart';
import 'package:ambot_app/widgets/chat_message_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dialogflow/dialogflow_v2.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:avatar_glow/avatar_glow.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _messageList = <ChatMessage>[];
  final _controllerText = new TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText _fala = stt.SpeechToText();
  bool _escutando = false;
  double _confianca = 1.0;
  String textoOuvido = '';

  @override
  void dispose() {
    super.dispose();
    _controllerText.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: new AppBar(
        title: Text('Ambot'),
      ),
      body: Column(
        children: <Widget>[
          _buildList(),
          Divider(height: 1.0),
          _buildUserInput(),
        ],
      ),
    );
  }

  // Cria a lista de mensagens (de baixo para cima)
  Widget _buildList() {
    return Flexible(
      child: ListView.builder(
        padding: EdgeInsets.all(8.0),
        reverse: true,
        itemBuilder: (_, int index) =>
            ChatMessageListItem(chatMessage: _messageList[index]),
        itemCount: _messageList.length,
      ),
    );
  }

  // Envia uma mensagem com o padrão a direita
  void _sendMessage({required String text}) {
    _controllerText.clear();
    _addMessage(name: 'Cliente', text: text, type: ChatMessageType.sent);
  }

  // Adiciona uma mensagem na lista de mensagens
  void _addMessage(
      {required String name,
      required String text,
      required ChatMessageType type}) {
    var message = ChatMessage(text: text, name: name, type: type);
    setState(() {
      _messageList.insert(0, message);
    });

    if (type == ChatMessageType.sent) {
      // Envia a mensagem para o chatbot e aguarda sua resposta
      _dialogFlowRequest(query: message.text);
    }
  }

  // Método incompleto ainda
  Future _dialogFlowRequest({required String query}) async {
    // Adiciona uma mensagem temporária na lista
    _addMessage(
        name: 'AmBot', text: 'Escrevendo...', type: ChatMessageType.received);

    // Faz a autenticação com o serviço, envia a mensagem e recebe uma resposta da Intent
    AuthGoogle authGoogle =
        await AuthGoogle(fileJson: "assets/credentials.json").build();
    Dialogflow dialogflow =
        Dialogflow(authGoogle: authGoogle, language: "pt-BR");
    AIResponse response = await dialogflow.detectIntent(query);

    // remove a mensagem temporária
    setState(() {
      _messageList.removeAt(0);
    });

    // adiciona a mensagem com a resposta do DialogFlow
    _addMessage(
        name: 'AmBot',
        text: response.getMessage() ?? '',
        type: ChatMessageType.received);
    String resposta = response.getMessage() ?? '';
    speak(resposta);
  }

  Future speak(String resposta) async {
    await flutterTts.speak(resposta);
  }

  void listen() async {
    if (!_escutando) {
      bool disponivel = await _fala.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (disponivel) {
        setState(() => _escutando = true);
        _fala.listen(
          onResult: (val) => setState(() {
            textoOuvido = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confianca = val.confidence;
            }
          }),
        );
      }
    } else {
      setState(() => _escutando = false);
      _fala.stop();
      _sendMessage(text: textoOuvido);
    }
  }

  Widget _buildVoiceField() {
    return new Container(
      width: 200,
      height: 100,
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: AvatarGlow(
          animate: _escutando,
          glowColor: Theme.of(context).primaryColor,
          endRadius: 75.0,
          duration: const Duration(milliseconds: 2000),
          repeatPauseDuration: const Duration(milliseconds: 100),
          repeat: true,
          child: FloatingActionButton(
            onPressed: listen,
            child: Icon(_escutando ? Icons.mic : Icons.mic_none),
          ),
        ),
        body: SingleChildScrollView(
            reverse: true,
            child: Text(
              textoOuvido,
              style: TextStyle(fontSize: 24),
            )),
      ),
    );
  }

  // Campo para escrever a mensagem
  Widget _buildTextField() {
    return new Flexible(
      child: new TextField(
        controller: _controllerText,
        decoration: new InputDecoration.collapsed(
          hintText: "Enviar mensagem",
        ),
      ),
    );
  }

  // Botão para enviar a mensagem
  Widget _buildSendButton() {
    return new Container(
      margin: new EdgeInsets.only(left: 8.0),
      child: new IconButton(
          icon: new Icon(Icons.send, color: Theme.of(context).accentColor),
          onPressed: () {
            if (_controllerText.text.isNotEmpty) {
              _sendMessage(text: _controllerText.text);
            }
          }),
    );
  }

  // Monta uma linha com o campo de text e o botão de enviao
  Widget _buildUserInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: new Row(
        children: <Widget>[
          _buildTextField(),
          _buildVoiceField(),
          _buildSendButton(),
        ],
      ),
    );
  }
}
