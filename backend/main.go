package main

import (
	"log"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type Post struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	Title     string    `json:"title" gorm:"not null"`
	Content   string    `json:"content" gorm:"not null"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt time.Time `json:"updated_at" gorm:"autoUpdateTime"`
}

var db *gorm.DB

func main() {
	// Initialize database
	var err error
	db, err = gorm.Open(sqlite.Open("posts.db"), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// Auto migrate the schema
	err = db.AutoMigrate(&Post{})
	if err != nil {
		log.Fatal("Failed to migrate database:", err)
	}

	// Create Fiber instance
	app := fiber.New(fiber.Config{
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			if e, ok := err.(*fiber.Error); ok {
				code = e.Code
			}
			return c.Status(code).JSON(fiber.Map{
				"error": err.Error(),
			})
		},
	})

	// Middleware
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowMethods: "GET,POST,PUT,DELETE,OPTIONS",
		AllowHeaders: "Origin,Content-Type,Accept,Authorization",
	}))
	
	app.Use(logger.New())

	// Routes
	api := app.Group("/api")

	// Posts routes
	api.Get("/posts", getPosts)
	api.Post("/posts", createPost)
	api.Get("/posts/:id", getPost)
	api.Put("/posts/:id", updatePost)
	api.Delete("/posts/:id", deletePost)

	// Health check
	api.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status": "ok",
			"time":   time.Now(),
		})
	})

	log.Println("Server starting on :3000")
	log.Fatal(app.Listen(":3000"))
}

func getPosts(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "10"))

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 10
	}

	offset := (page - 1) * limit

	var posts []Post
	var total int64

	// Get total count
	if err := db.Model(&Post{}).Count(&total).Error; err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to count posts")
	}

	// Get posts with pagination
	if err := db.Order("created_at DESC").Offset(offset).Limit(limit).Find(&posts).Error; err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch posts")
	}

	return c.JSON(fiber.Map{
		"posts":       posts,
		"total":       total,
		"page":        page,
		"limit":       limit,
		"total_pages": (total + int64(limit) - 1) / int64(limit),
	})
}

func createPost(c *fiber.Ctx) error {
	body := c.Body()
	log.Printf("Received POST body: %s", string(body))
	
	post := new(Post)

	if err := c.BodyParser(post); err != nil {
		log.Printf("Error parsing JSON: %v", err)
		return fiber.NewError(fiber.StatusBadRequest, "Cannot parse JSON")
	}

	// Validate required fields
	if post.Title == "" || post.Content == "" {
		return fiber.NewError(fiber.StatusBadRequest, "Title and content are required")
	}

	// Set timestamps
	now := time.Now()
	post.CreatedAt = now
	post.UpdatedAt = now

	if err := db.Create(&post).Error; err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to create post")
	}

	return c.Status(fiber.StatusCreated).JSON(post)
}

func getPost(c *fiber.Ctx) error {
	id := c.Params("id")
	
	var post Post
	if err := db.First(&post, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return fiber.NewError(fiber.StatusNotFound, "Post not found")
		}
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch post")
	}

	return c.JSON(post)
}

func updatePost(c *fiber.Ctx) error {
	id := c.Params("id")
	
	body := c.Body()
	log.Printf("Received PUT body: %s", string(body))
	
	var post Post
	if err := db.First(&post, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return fiber.NewError(fiber.StatusNotFound, "Post not found")
		}
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch post")
	}

	var updateData Post
	if err := c.BodyParser(&updateData); err != nil {
		log.Printf("Error parsing PUT JSON: %v", err)
		return fiber.NewError(fiber.StatusBadRequest, "Cannot parse JSON")
	}

	// Validate required fields
	if updateData.Title == "" || updateData.Content == "" {
		return fiber.NewError(fiber.StatusBadRequest, "Title and content are required")
	}

	// Update fields
	post.Title = updateData.Title
	post.Content = updateData.Content
	post.UpdatedAt = time.Now()

	if err := db.Save(&post).Error; err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to update post")
	}

	return c.JSON(post)
}

func deletePost(c *fiber.Ctx) error {
	id := c.Params("id")
	
	var post Post
	if err := db.First(&post, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return fiber.NewError(fiber.StatusNotFound, "Post not found")
		}
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to fetch post")
	}

	if err := db.Delete(&post).Error; err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "Failed to delete post")
	}

	return c.JSON(fiber.Map{
		"message": "Post deleted successfully",
	})
}