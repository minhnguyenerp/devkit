# Use Minh Nguyen DevKit to create a Go - Gin project

Open [**Minh Nguyen DevKit**](../README.md) terminal, navigate to your project container folder e.g `C:\Data\projects`.

Create the project folder `mkdir hello-gin` and then change the current directory to `cd hello-gin`.

Run <code>go mod init hello-gin</code>

Run <code>go get github.com/gin-gonic/gin</code>

Type `code .` and press **Enter** to open project in VSCode

In VSCode, create *hello-gin/main.go* file as following:

<h5><strong><code>main.go</code></strong></h5>

```golang
package main

import (
    "github.com/gin-gonic/gin"
    "net/http"
)

func main() {
    r := gin.Default()

    r.GET("/", func(c *gin.Context) {
        c.JSON(http.StatusOK, gin.H{
            "message": "Hello, Gin!",
        })
    })

    r.Run(":3000")
}
```

Open the VSCode Terminal or DevKit terminal and run program <code>go run .</code>, then open browser and navigate to `http://localhost:3000/` to see the result.

Command to build release <code>go build -ldflags "-s -w" -o bin/hello-gin.exe</code>.
