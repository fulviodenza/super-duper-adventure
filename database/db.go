package database

import "super-duper-adventure/model"

// Temporary solution waiting for the managed AWS database

var db []model.Task

func Insert(task *model.Task) error {

	db = append(db, *task)
	return nil
}

func Get() []model.Task {
	return db
}
