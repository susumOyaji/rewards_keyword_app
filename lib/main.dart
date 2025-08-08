import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as html;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microsoft Rewards Keywords',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const KeywordListScreen(),
    );
  }
}

class KeywordListScreen extends StatefulWidget {
  const KeywordListScreen({super.key});

  @override
  State<KeywordListScreen> createState() => _KeywordListScreenState();
}

class _KeywordListScreenState extends State<KeywordListScreen> {
  List<KeywordCategory> _keywordCategories = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedKeyword; // 選択されたキーワードを保持する変数

  @override
  void initState() {
    super.initState();
    _fetchKeywords();
  }

  Future<void> _fetchKeywords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse('https://yoshizo.hatenablog.com/entry/microsoft-rewards-search-keyword-list/#movie'));

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final List<KeywordCategory> fetchedCategories = [];

        final h3Elements = document.querySelectorAll('h3');

        for (var h3 in h3Elements) {
          final categoryName = h3.text.trim();
          List<String> keywords = [];

          html.Element? currentElement = h3.nextElementSibling;
          html.Element? foundUl;

          // Iterate through siblings until a UL is found or another H3 is encountered
          while (currentElement != null) {
            if (currentElement.localName == 'ul') {
              foundUl = currentElement;
              break; // Found the ul as a direct sibling
            }
            // If we encounter another h3, it means we've passed the current category's content
            if (currentElement.localName == 'h3') {
              break;
            }
            // Check if ul is a descendant of the current element (e.g., ul inside a div or p)
            final ulInDescendants = currentElement.querySelector('ul');
            if (ulInDescendants != null) {
              foundUl = ulInDescendants;
              break; // Found the ul within a descendant
            }

            currentElement = currentElement.nextElementSibling;
          }

          if (foundUl != null) {
            final liElements = foundUl.querySelectorAll('li');
            for (var li in liElements) {
              String rawKeywordText = li.text.trim();
              String keywordText = rawKeywordText.replaceAll(RegExp(r'\(.*?\)'), '').trim();
              keywordText = keywordText.replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
              keywordText = keywordText.replaceAll(RegExp(r'^-+\s*'), '').trim();

              if (keywordText.isNotEmpty) {
                keywords.add(keywordText);
              }
            }
          } else {
            // No ul element found after h3 for category
          }
          if (keywords.isNotEmpty) {
            fetchedCategories.add(KeywordCategory(name: categoryName, keywords: keywords));
          } else {
            // No keywords extracted for category
          }
        }

        setState(() {
          _keywordCategories = fetchedCategories;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load keywords: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e, stacktrace) {
      setState(() {
        _error = 'Error fetching keywords: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Microsoft Rewards Keywords'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0), // HTML body padding
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : ListView.builder(
                    itemCount: _keywordCategories.length,
                    itemBuilder: (context, index) {
                      final category = _keywordCategories[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(bottom: 5.0, top: 10.0), // h2 padding-bottom and top for spacing
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFCCCCCC), width: 1.0), // h2 border-bottom
                              ),
                            ),
                            child: Text(
                              category.name,
                              style: const TextStyle(color: Color(0xFF555555), fontSize: 18.0, fontWeight: FontWeight.bold), // h2 color and style
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20.0, top: 10.0, bottom: 10.0), // ul margin-left and vertical spacing
                            child: Wrap(
                              spacing: 8.0, // space between chips
                              runSpacing: 4.0, // space between lines of chips
                                                            children: category.keywords.map((keyword) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min, // Rowを内容のサイズに合わせる
                                  children: [
                                    Radio<String>(
                                      value: keyword,
                                      groupValue: _selectedKeyword,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedKeyword = value;
                                        });
                                      },
                                    ),
                                    Text(keyword),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}

class KeywordCategory {
  final String name;
  final List<String> keywords;

  KeywordCategory({required this.name, required this.keywords});
}