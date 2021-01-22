/*
* Author: Richard Teemal
* Copyright2021 TeemalTech Solutions
* All Rights Reserved
* */

//import 'dart:html';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soundpool/soundpool.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Soundpool _soundpool;
//int _barkStreamId;
Future<int> _barkId;
bool _firstRun = true;
bool _connected = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(Woofly());
}

class Woofly extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doggy Finder',
      theme: ThemeData(
          primarySwatch: Colors.brown,
          selectedRowColor: Colors.amberAccent,
          secondaryHeaderColor: Colors.amber),
      home: LandingPage(title: 'Doggo Finder'),
    );
  }
}

class LandingPage extends StatefulWidget {
  LandingPage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _LandingPageState createState() => _LandingPageState();
}

class Breed {
  String breedName;
  String thumbUrl;

  Breed(b, t) {
    this.breedName = b;
    this.thumbUrl = t;
  }
}

class AllBreeds {
  List<Breed> dogsList;
  AllBreeds(dl) {
    this.dogsList = dl;
  }
}

class checkInternet {
  StreamSubscription<DataConnectionStatus> listener;
  var InternetStatus = "Unknown";
  var contentmessage = "Unknown";

  void _showDialog(String title, String content, BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: new Text(title),
              content: new Text(content),
              actions: <Widget>[
                new FlatButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: new Text("Close"))
              ]);
        });
  }

  checkConnection(BuildContext context) async {
    listener = DataConnectionChecker().onStatusChange.listen((status) {
      switch (status) {
        case DataConnectionStatus.connected:
          _connected = true;
          InternetStatus = "Connected";
          contentmessage = "You are Connected to the Internet";
          if (!_firstRun) {
            _showDialog(InternetStatus, contentmessage, context);
          }
          break;
        case DataConnectionStatus.disconnected:
          _connected = false;

          InternetStatus = "You are disconnected to the Internet. ";
          contentmessage = "Please check your internet connection";
          _showDialog(InternetStatus, contentmessage, context);
          break;
      }
      _firstRun = false;
    });
    return await DataConnectionChecker().connectionStatus;
  }
}

class _LandingPageState extends State<LandingPage> {
  final api = "https://dog.ceo/api/breeds/list";
  final apiRoot = "https://dog.ceo/api/breed";
  bool isConnected = false;
  bool _loading = true;
  int count = 0;
  int _selectedIndex = 0;
  List<Breed> masterList = <Breed>[];
  List<String> urls = <String>[];
  Future<List<Breed>> futureList;
  final _biggerFont = TextStyle(fontSize: 18.0, color: Colors.brown[900]);

  void _showDialog(String title, String content, BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: new Text(title),
              content: new Text(content),
              actions: <Widget>[
                new FlatButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: new Text("Close"))
              ]);
        });
  }

  Future<List<Breed>> fetchAllBreeds() async {
    List<Breed> fetched = [];
    List<dynamic> bList = [];
    var response = await http.get(api);
    if (response.statusCode == 200) {
      var obj = jsonDecode(response.body);
      bList = obj['message'];
      //iterate over List to create List
      for (var i = 0; i < bList.length; i++) {
        var breedName = bList[i];
        Breed b = Breed(breedName,
            "https://firebasestorage.googleapis.com/v0/b/teemaltech-solutions.appspot.com/o/placeholder.png?alt=media&token=bca09da0-e146-455c-aca6-875138a390fa");
        fetched.add(b);
      }
      setState(() {
        masterList = fetched;
      });
      loadImages();
      return fetched;
    } else {
      _showDialog("Unable to reach servers",
          "Our servers may be down. Please try back later.", context);
    }
  }

  void loadImages() {
    for (var i = 0; i < masterList.length; i++) {
      Future imgFuture =
          http.get(apiRoot + '/' + masterList[i].breedName + '/images/random');
      imgFuture.then((resp) {
        if (resp.statusCode == 200) {
          var obj = jsonDecode(resp.body);
          String url = obj['message'];
          setImgURL(url, i);
        } else {
          //TODO ADD EXCEPTION HANDLER
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _soundpool = Soundpool(maxStreams: 2);
    _loadSounds();
    Future internetCheck = checkInternet().checkConnection(context);
    internetCheck.then((value) {
      if (value == DataConnectionStatus.connected) {
        futureList = fetchAllBreeds();
      }
    });
  }

  @override
  void dispose() {
    checkInternet().listener.cancel();
    super.dispose();
  }

  void goDetails(breed) {
    //bark();
    if (_connected)
      Navigator.push(context, MaterialPageRoute(builder: (_) {
        return DetailScreen(breed);
      }));
  }

  String getImgURL(index) {
    return masterList[index].thumbUrl;
  }

  void setImgURL(url, index) {
    this.masterList[index].thumbUrl = url;
    this.count++;
    //print("the count is: ${this.count}");
    if (count == this.masterList.length) {
      setState(() {
        _loading = false;
        print("All items loaded, refreshing state now...");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: EdgeInsets.only(left: 10.0),
          child: Image.asset('assets/images/placeholder.png'),
        ),
        title: Text(widget.title),
      ),
      body: Center(
        child: FutureBuilder<List<Breed>>(
          future: futureList,
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return CircularProgressIndicator();
              case ConnectionState.done:
                if (snapshot.hasError) {
                  _showDialog(
                      "Unable to reach servers",
                      "Our servers may be down. Please try back later.",
                      context);
                  return CircularProgressIndicator();
                } else if (snapshot.hasData) {
                  List<Breed> breedList = snapshot.data;
                  return ListView.builder(
                      padding: EdgeInsets.all(16.0),
                      shrinkWrap: true,
                      itemBuilder: (context, i) {
                        if (i.isOdd) return Divider();
                        final index = i ~/ 2;
                        if (index < breedList.length) {
                          return ListTile(
                            onTap: () =>
                                {goDetails(breedList[index].breedName)},
                            leading: SizedBox(
                              width: 75,
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: FadeInImage.memoryNetwork(
                                  placeholder: kTransparentImage,
                                  image: getImgURL(index),
                                ),
                              ),
                            ),
                            title: Text(
                              breedList[index].breedName,
                              style: _biggerFont,
                            ),
                          );
                        } else {
                          return null;
                        }
                      });
                }
                break;
              case ConnectionState.active:
                //TODO put activity here
                break;
            }
            return CircularProgressIndicator();
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Icon(Icons.web),
                title: Text('Developer website'),
                backgroundColor: Colors.brown),
            BottomNavigationBarItem(
                icon: Icon(Icons.email),
                title: Text('email'),
                backgroundColor: Colors.brown),
          ],
          type: BottomNavigationBarType.shifting,
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          onTap: _onItemTapped,
          iconSize: 40,
          elevation: 5),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (_selectedIndex == 0) {
      if (_connected)
        Navigator.push(context, MaterialPageRoute(builder: (_) {
          String devURL = 'https://teemaltech-solutions.firebaseapp.com/';
          return WebViewContainer(devURL: devURL);
        }));
    }
  }
}

// ignore: must_be_immutable
class DetailScreen extends StatefulWidget {
  String selected;
  DetailScreen(sel) {
    this.selected = sel;
  }
  @override
  _DetailScreenState createState() => _DetailScreenState(selected);
}

class _DetailScreenState extends State<DetailScreen> {
  Future<List<dynamic>> imgList;
  String selected;
  _DetailScreenState(sel) {
    this.selected = sel;
  }
  void _showDialog(String title, String content, BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: new Text(title),
              content: new Text(content),
              actions: <Widget>[
                new FlatButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: new Text("Close"))
              ]);
        });
  }

  void goBigOrGoHome(imgurl) {
    bark();
    if (_connected)
      Navigator.push(context, MaterialPageRoute(builder: (_) {
        return BigScreen(imgURL: imgurl);
      }));
  }

  Future<List<dynamic>> fetchAlbum(selected) async {
    final String api = "https://dog.ceo/api/breed/" + selected + "/images/";
    var response = await http.get(api);
    if (response.statusCode == 200) {
      Map<String, dynamic> obj = jsonDecode(response.body);
      return obj['message'];
    } else {
      _showDialog("Unable to reach servers",
          "Our servers may be down. Please try back later.", context);
      throw Exception('Failed to load dog images');
    }
  }

  @override
  void initState() {
    super.initState();
    imgList = fetchAlbum(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Image.asset('assets/images/placeholder.png'),
        title: Text(widget.selected),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.reply),
            tooltip: 'Go Back',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Center(
          child: Hero(
            tag: 'imageHero',
            child: FutureBuilder<List<dynamic>>(
              future: imgList,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  List<dynamic> images = snapshot.data;
                  List<Widget> warr = [];
                  for (var i = 0; i < images.length; i++) {
                    warr.add(
                      GestureDetector(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          child: FadeInImage.memoryNetwork(
                            placeholder: kTransparentImage,
                            image: images[i],
                          ),
                        ),
                        onTap: () {
                          goBigOrGoHome(images[i]);
                        },
                      ),
                    );
                  }
                  return GridView.count(
                    primary: false,
                    padding: const EdgeInsets.all(5),
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    crossAxisCount: 3,
                    children: warr,
                  );
                } else if (snapshot.hasError) {
                  return Text("${snapshot.error}");
                }

                // By default, show a loading spinner.
                return CircularProgressIndicator();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class BigScreen extends StatefulWidget {
  BigScreen({Key key, this.imgURL}) : super(key: key);
  final String imgURL;
  @override
  State<StatefulWidget> createState() {
    return _BigScreenState(imgURL);
  }
}

class _BigScreenState extends State<BigScreen> {
  String img = '';
  _BigScreenState(imgurl) {
    this.img = imgurl;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        child: Center(
          child: Hero(
              tag: 'bigImage',
              child: Image.network(this.img, fit: BoxFit.fitWidth)),
        ),
        onTap: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}

class WebViewContainer extends StatefulWidget {
  WebViewContainer({Key key, this.devURL}) : super(key: key);
  final String devURL;
  @override
  createState() => _WebViewContainerState(this.devURL);
}

class _WebViewContainerState extends State<WebViewContainer> {
  var _devurl;
  bool isLoading = true;
  final _key = UniqueKey();
  _WebViewContainerState(this._devurl);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TeemalTech Solutions'),
      ),
      body: Stack(
        children: <Widget>[
          WebView(
            key: _key,
            initialUrl: this._devurl,
            javascriptMode: JavascriptMode.unrestricted,
            onPageFinished: (finish) {
              setState(() {
                isLoading = false;
              });
            },
          ),
          isLoading
              ? Center(
                  child: CircularProgressIndicator(),
                )
              : Stack(),
        ],
      ),
    );
  }
}

Future<int> _loadSound() async {
  var asset = await rootBundle.load("assets/sounds/woof.wav");
  return await _soundpool.load(asset);
}

Future<void> bark() async {
  var _barkSound = await _barkId;
  await _soundpool.play(_barkSound);
}

Future<void> _loadSounds() async {
  _soundpool ??= Soundpool();
  _barkId = _loadSound();
}
