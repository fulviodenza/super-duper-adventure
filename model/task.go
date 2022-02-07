package model

type Task struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Status      string `json:"status"`
}
