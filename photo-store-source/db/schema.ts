import {sqliteTable,text,integer} from 'drizzle-orm/sqlite-core';
export const events=sqliteTable('events',{id:text('id').primaryKey(),title:text('title').notNull(),date:text('date').notNull(),location:text('location').notNull(),price:integer('price').notNull(),pack:integer('pack').notNull()});
export const photos=sqliteTable('photos',{id:text('id').primaryKey(),event:text('event').notNull(),label:text('label').notNull(),original:text('original').notNull(),preview:text('preview').notNull(),uploader:text('uploader').notNull(),removed:integer('removed').notNull().default(0)});
export const members=sqliteTable('members',{email:text('email').primaryKey()});
export const orders=sqliteTable('orders',{id:text('id').primaryKey(),user:text('user').notNull(),email:text('email').notNull(),event:text('event').notNull(),photos:text('photos').notNull(),price:integer('price').notNull(),status:text('status').notNull(),created:text('created').notNull()});
