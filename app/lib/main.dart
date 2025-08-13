import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'helper/save_helper.dart'
    if (dart.library.html) 'helper/save_helper_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PdfViewer(),
  ));
}

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

// Post model
class Post {
  final int? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    
    if (id != null) {
      data['id'] = id;
    }
    
    return data;
  }
}

class _PdfViewerState extends State<PdfViewer> with TickerProviderStateMixin {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  String? _pdfFilePath;
  double _zoomLevel = 1.0;
  bool _isLoading = false;
  bool _showSidebar = false;
  bool _showPostsSidebar = true;
  int _totalPages = 0;
  double _loadingProgress = 0.0;
  String _loadingStatus = 'Loading...';
  AnimationController? _loadingAnimationController;
  Animation<double>? _loadingAnimation;
  
  // Posts management
  List<Post> _posts = [];
  bool _postsLoading = false;
  int _currentPage = 1;
  bool _hasMorePosts = true;
  Post? _selectedPost;
  final String _baseUrl = 'http://localhost:3000/api';

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _initializeAnimation();
  }
  
  void _initializeAnimation() {
    _loadingAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController!,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _loadingAnimationController?.dispose();
    super.dispose();
  }

  /// Simulate loading with smooth progress without blocking I/O
  Future<void> _simulateLoadingProgress() async {
    // Start loading animation
    _loadingAnimationController?.repeat();
    
    // Simulate gradual progress updates
    final progressSteps = [
      (0.1, 'Initializing...', 150),
      (0.25, 'Reading file...', 200),
      (0.5, 'Processing...', 300),
      (0.75, 'Rendering...', 250),
      (0.9, 'Almost done...', 200),
      (1.0, 'Complete', 100),
    ];
    
    for (final (progress, status, delayMs) in progressSteps) {
      if (!mounted) break;
      
      setState(() {
        _loadingProgress = progress;
        _loadingStatus = status;
      });
      
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    
    // Stop animation
    _loadingAnimationController?.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _pdfFilePath != null
          ? Text('Page ${_pdfViewerController.pageNumber}/${_pdfViewerController.pageCount}')
          : null,
        actions: [
          IconButton(onPressed: _openFile, icon: const Icon(Icons.folder_open)),
          IconButton(onPressed: _saveFile, icon: const Icon(Icons.save)),
          IconButton(
            onPressed: () {
              setState(() {
                _showPostsSidebar = !_showPostsSidebar;
              });
            },
            icon: Icon(_showPostsSidebar ? Icons.article : Icons.article_outlined),
            tooltip: _showPostsSidebar ? 'Hide Posts' : 'Show Posts',
          ),
          IconButton(
            onPressed: _selectedPost != null ? () => _showEditPostDialog(_selectedPost) : () => _showAddPostDialog(),
            icon: Icon(_selectedPost != null ? Icons.edit : Icons.add),
            tooltip: _selectedPost != null ? 'Edit Post' : 'Add Post',
          ),
          if (_selectedPost != null)
            IconButton(
              onPressed: () => _deletePost(_selectedPost!.id!),
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Post',
              color: Colors.red,
            ),
          if (_pdfFilePath != null) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _showSidebar = !_showSidebar;
                });
              },
              icon: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
              tooltip: _showSidebar ? 'Hide Thumbnails' : 'Show Thumbnails',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'zoom_in':
                    _zoomIn();
                    break;
                  case 'zoom_out':
                    _zoomOut();
                    break;
                  case 'prev_page':
                    _previousPage();
                    break;
                  case 'next_page':
                    _nextPage();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'zoom_in',
                  child: Row(
                    children: [
                      Icon(Icons.zoom_in),
                      SizedBox(width: 8),
                      Text('Zoom In'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'zoom_out',
                  child: Row(
                    children: [
                      Icon(Icons.zoom_out),
                      SizedBox(width: 8),
                      Text('Zoom Out'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'prev_page',
                  child: Row(
                    children: [
                      Icon(Icons.navigate_before),
                      SizedBox(width: 8),
                      Text('Previous Page'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'next_page',
                  child: Row(
                    children: [
                      Icon(Icons.navigate_next),
                      SizedBox(width: 8),
                      Text('Next Page'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Row(
        children: [
          // Left sidebar - PDF thumbnails (only when PDF is loaded)
          if (_showSidebar && _pdfFilePath != null) ...[
            Container(
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  right: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: _buildThumbnailSidebar(),
            ),
          ],
          
          // Main content area
          Expanded(
            child: _pdfFilePath == null
                ? const Center(
                    child: Text('Choose a PDF file to open'),
                  )
                : _isLoading
                    ? Center(
                        child: AnimatedBuilder(
                          animation: _loadingAnimation ?? const AlwaysStoppedAnimation(0.0),
                          builder: (context, child) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    value: _loadingProgress > 0 ? _loadingProgress : null,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  child: Text(_loadingStatus),
                                ),
                                const SizedBox(height: 12),
                                if (_loadingProgress > 0) ...[
                                  TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 200),
                                    tween: Tween(begin: 0, end: _loadingProgress),
                                    builder: (context, value, child) {
                                      return Column(
                                        children: [
                                          Container(
                                            width: 200,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: value,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).primaryColor,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${(value * 100).toInt()}%',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Zoom: ${(_zoomLevel * 100).toInt()}%'),
                                const SizedBox(width: 20),
                                Flexible(
                                  child: Slider(
                                    value: _zoomLevel,
                                    min: 0.5,
                                    max: 3.0,
                                    divisions: 25,
                                    label: '${(_zoomLevel * 100).toInt()}%',
                                    onChanged: (value) {
                                      setState(() {
                                        _zoomLevel = value;
                                      });
                                      _pdfViewerController.zoomLevel = value;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: _showPostsSidebar ? double.infinity : 800,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: _buildPdfViewer(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
          
          // Right sidebar - Posts (always available)
          if (_showPostsSidebar) ...[
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  left: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: _buildPostsSidebar(),
            ),
          ],
        ],
      ),
    );
  }

  /// Open a PDF file from the local device's storage.
  Future<void> _openFile() async {
    try {
      FilePickerResult? filePickerResult = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

      if (filePickerResult != null) {
        final file = filePickerResult.files.single;
        print('File selected: ${file.name}, size: ${(file.size / 1024 / 1024).toStringAsFixed(1)}MB');
        
        setState(() {
          _isLoading = true;
          _pdfFilePath = null;
          _loadingProgress = 0.0;
          _loadingStatus = 'Initializing...';
        });
        
        final filePath = !kIsWeb ? file.path! : null;
        
        if (kIsWeb) {
          print('Web platform not fully supported for file-based loading');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Web platform: Please use desktop/mobile version for better performance'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        print('Loading file from path: $filePath');
        
        // Use file-based loading for all files to avoid memory issues and UI blocking
        await _simulateLoadingProgress();
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _pdfFilePath = filePath;
          });
        }
      } else {
        print('No file selected');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _pdfFilePath = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading PDF: $e')),
        );
      }
    }
  }

  Widget _buildPdfViewer() {
    // Use file-based viewer only (no memory loading)
    return SfPdfViewer.file(
      File(_pdfFilePath!),
      controller: _pdfViewerController,
      pageLayoutMode: PdfPageLayoutMode.single,
      scrollDirection: PdfScrollDirection.vertical,
      pageSpacing: 4,
      canShowPaginationDialog: false,
      enableTextSelection: true,
      enableHyperlinkNavigation: true,
      onPageChanged: (PdfPageChangedDetails details) {
        if (mounted) {
          setState(() {});
        }
      },
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        print('PDF loaded successfully: ${details.document.pages.count} pages');
        if (mounted) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF loaded: ${details.document.pages.count} pages'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        print('PDF load failed: ${details.error}, ${details.description}');
        if (mounted) {
          setState(() {
            _pdfFilePath = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load PDF: ${details.description}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  Widget _buildThumbnailSidebar() {
    if (_totalPages == 0) {
      return const Center(
        child: Text('Loading thumbnails...'),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.photo_library, size: 16),
              const SizedBox(width: 8),
              Text(
                'Pages',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _totalPages,
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              final isCurrentPage = _pdfViewerController.pageNumber == pageNumber;
              
              return Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isCurrentPage ? Colors.blue : Colors.grey[300]!,
                    width: isCurrentPage ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Material(
                  color: isCurrentPage ? Colors.blue[50] : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      _pdfViewerController.jumpToPage(pageNumber);
                    },
                    child: Container(
                      height: 120,
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: _buildThumbnail(pageNumber),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$pageNumber',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentPage ? Colors.blue[700] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(int pageNumber) {
    return FutureBuilder<Widget?>(
      future: _generateThumbnail(pageNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.grey[400], size: 20),
                const SizedBox(height: 2),
                Text(
                  '$pageNumber',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }
        
        return snapshot.data!;
      },
    );
  }

  Future<Widget?> _generateThumbnail(int pageNumber) async {
    try {
      // For performance, we'll create a simple placeholder thumbnail
      // In a real implementation, you might want to use a PDF rendering library
      // to generate actual page thumbnails
      await Future.delayed(const Duration(milliseconds: 50));
      
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[100]!,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description,
                color: Colors.grey[400],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                'Page',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Widget _buildPostsSidebar() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.article, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Posts (${_posts.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _showAddPostDialog(),
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Add Post',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _posts.isEmpty && !_postsLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.article_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No posts yet'),
                    Text('Click + to add a post', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (!_postsLoading && _hasMorePosts && scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                    _loadMorePosts();
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _posts.length + (_postsLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _posts.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    
                    final post = _posts[index];
                    final isSelected = _selectedPost?.id == post.id;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      elevation: isSelected ? 4 : 1,
                      color: isSelected ? Colors.blue[50] : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() {
                            _selectedPost = isSelected ? null : post;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      post.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? Colors.blue[700] : null,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    IconButton(
                                      onPressed: () => _showEditPostDialog(post),
                                      icon: const Icon(Icons.edit, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Edit',
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: () => _deletePost(post.id!),
                                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                post.content,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDate(post.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // CRUD Operations
  Future<void> _loadPosts() async {
    if (_postsLoading) return;
    
    setState(() {
      _postsLoading = true;
      _currentPage = 1;
      _posts.clear();
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/posts?page=$_currentPage&limit=10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> postsJson = data['posts'] ?? [];
        final List<Post> newPosts = postsJson.map((json) => Post.fromJson(json)).toList();
        
        setState(() {
          _posts = newPosts;
          _hasMorePosts = newPosts.length == 10;
          _currentPage = 2;
        });
      }
    } catch (e) {
      print('Error loading posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
    } finally {
      setState(() {
        _postsLoading = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_postsLoading || !_hasMorePosts) return;
    
    setState(() {
      _postsLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/posts?page=$_currentPage&limit=10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> postsJson = data['posts'] ?? [];
        final List<Post> newPosts = postsJson.map((json) => Post.fromJson(json)).toList();
        
        setState(() {
          _posts.addAll(newPosts);
          _hasMorePosts = newPosts.length == 10;
          _currentPage++;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
    } finally {
      setState(() {
        _postsLoading = false;
      });
    }
  }

  Future<void> _createPost(String title, String content) async {
    try {
      final postData = {
        'title': title,
        'content': content,
      };

      print('Sending POST data: ${json.encode(postData)}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/posts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        final newPost = Post.fromJson(json.decode(response.body));
        setState(() {
          _posts.insert(0, newPost);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post created successfully')),
          );
        }
      } else {
        print('Failed to create post: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create post: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    }
  }

  Future<void> _updatePost(Post post) async {
    try {
      final updateData = {
        'title': post.title,
        'content': post.content,
      };

      print('Sending PUT data: ${json.encode(updateData)}');

      final response = await http.put(
        Uri.parse('$_baseUrl/posts/${post.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          setState(() {
            _posts[index] = Post.fromJson(json.decode(response.body));
            _selectedPost = _posts[index];
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post updated successfully')),
          );
        }
      }
    } catch (e) {
      print('Error updating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update post: $e')),
        );
      }
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/posts/$postId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _posts.removeWhere((post) => post.id == postId);
          if (_selectedPost?.id == postId) {
            _selectedPost = null;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
        }
      }
    } catch (e) {
      print('Error deleting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  void _showAddPostDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Post'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                _createPost(titleController.text, contentController.text);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog(Post? post) {
    if (post == null) return;
    
    final titleController = TextEditingController(text: post.title);
    final contentController = TextEditingController(text: post.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Post'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                final updatedPost = Post(
                  id: post.id,
                  title: titleController.text,
                  content: contentController.text,
                  createdAt: post.createdAt,
                  updatedAt: DateTime.now(),
                );
                _updatePost(updatedPost);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  /// Save a PDF file to the desired local device's storage location.
  Future<void> _saveFile() async {
    if (_pdfViewerController.pageCount > 0) {
      List<int> bytes = await _pdfViewerController.saveDocument();
      SaveHelper.save(bytes, 'Saved.pdf');
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.25).clamp(0.5, 3.0);
    });
    _pdfViewerController.zoomLevel = _zoomLevel;
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.25).clamp(0.5, 3.0);
    });
    _pdfViewerController.zoomLevel = _zoomLevel;
  }

  void _previousPage() {
    if (_pdfViewerController.pageNumber > 1) {
      _pdfViewerController.previousPage();
    }
  }

  void _nextPage() {
    if (_pdfViewerController.pageNumber < _pdfViewerController.pageCount) {
      _pdfViewerController.nextPage();
    }
  }
}
