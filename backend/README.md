# Posts Backend API

Go/Fiber backend with SQLite database for managing posts.

## Setup

1. Install Go dependencies:
```bash
go mod tidy
```

2. Run the server:
```bash
go run main.go
```

The server will start on `http://localhost:3000`

## API Endpoints

### Get Posts (with pagination)
```
GET /api/posts?page=1&limit=10
```

### Create Post
```
POST /api/posts
Content-Type: application/json

{
  "title": "Post Title",
  "content": "Post content here"
}
```

### Get Single Post
```
GET /api/posts/:id
```

### Update Post
```
PUT /api/posts/:id
Content-Type: application/json

{
  "title": "Updated Title",
  "content": "Updated content"
}
```

### Delete Post
```
DELETE /api/posts/:id
```

### Health Check
```
GET /api/health
```

## Database

- Uses SQLite with `posts.db` file
- Auto-migration enabled
- GORM as ORM

## Features

- CORS enabled for frontend integration
- Request logging
- Error handling
- Pagination support
- Input validation