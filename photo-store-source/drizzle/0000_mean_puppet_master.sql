CREATE TABLE `events` (
	`id` text PRIMARY KEY NOT NULL,
	`title` text NOT NULL,
	`date` text NOT NULL,
	`location` text NOT NULL,
	`price` integer NOT NULL,
	`pack` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `members` (
	`email` text PRIMARY KEY NOT NULL
);
--> statement-breakpoint
CREATE TABLE `orders` (
	`id` text PRIMARY KEY NOT NULL,
	`user` text NOT NULL,
	`email` text NOT NULL,
	`event` text NOT NULL,
	`photos` text NOT NULL,
	`price` integer NOT NULL,
	`status` text NOT NULL,
	`created` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `photos` (
	`id` text PRIMARY KEY NOT NULL,
	`event` text NOT NULL,
	`label` text NOT NULL,
	`original` text NOT NULL,
	`preview` text NOT NULL,
	`uploader` text NOT NULL
);
