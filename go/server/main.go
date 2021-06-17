package main

import (
	"fmt"
	"net"
	"os"

	"github.com/ymmt2005/grpc-tutorial/go/deepthought"
	"google.golang.org/grpc"
)

const portNumber = 13333

func main() {
	serv := grpc.NewServer()
	deepthought.RegisterComputeServer(serv, &Server{})

	l, err := net.Listen("tcp", fmt.Sprintf(":%d", portNumber))
	if err != nil {
		fmt.Println("failed to listen:", err)
		os.Exit(1)
	}

	serv.Serve(l)
}
