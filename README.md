# Kaplan

## Summary

Kaplan provides some Rake tasks that are helpful in preparing your test database(s), such as seeding/plowing your database, or recreating it from your development database.

For instance, let's say you ran your unit tests, and somehow the database wasn't rolled back correctly. Simply run `rake kaplan:db:reset` -- that will dump the SQL schema for your development database to file and use it to replace your test database, then it will seed your test database.

A more common scenario might be, you ran your Cucumber tests and now you need to reset your integration test database back to zero before you run them again. In that case, add `Kaplan.plow_database()` to your Cucumber initialization file and all is well.

## Rationale

Doesn't Rails already provide a `db:reset` Rake task? Yes, but it runs `db:schema:dump` and `db:schema:load` behind the scenes, which isn't always a foolproof way of dumping your schema (there are a few cases, like custom `id` columns, where Rails drops the ball). `db:clone_structure` is almost always the better way to go. Also, eventually you'll reach a point in your Rails app where you need some data to be always in your development and test databases -- in other words, seed data. It would be nice if the `reset` task also seeded your test database too. Kaplan's `db:reset` task does both of these things.

Also, Rails doesn't give you a way to programmatically reset (or at least seed) your database. So if you want to do it inside of a script, you're forced to `require 'rake'` and then say `Rake::Task.invoke["db:reset"]`. That's ridiculous. Kaplan gives you methods for plowing and seeding the database.

Finally, Kaplan improves Rails' seeding by 1) truncating the tables that will be seeded first, 2) allowing you to keep environment-specific seed files, and 2) allowing you to use YAML or text files since that's a simpler way of representing data (and you're probably used to seeing YAML for fixture data).

## Usage

Here are the Rake tasks.

* **kaplan:db:reset** - Resets the database corresponding to the given environment by re-creating it from the development schema and then re-seeding it. Accepts: `RAILS_ENV` (required, must not be "development").
* **kaplan:db:seed** - Seeds the database corresponding to the given environment with bootstrap data. The tables that will be seeded are truncated first so you don't have to. Accepts: `RAILS_ENV` (optional, default is "development").
* **kaplan:db:plow** - Truncates tables in the database corresponding to the given environment. By default this just truncates the seed tables, pass `ALL` to truncate everything. Accepts: `RAILS_ENV` (optional, default is "development"), `ALL` (optional).
* **kaplan:db:clone_structure** - Dumps the structure of the development database to file and copies it to the database corresponding to the given environment. The adapters between the databases must be the same. Accepts: `RAILS_ENV` (required, must not be "development").
* **kaplan:db:create** - Creates the database corresponding to the given environment. Accepts: `RAILS_ENV` (optional, default is "development").
* **kaplan:db:drop** - Drops the database corresponding to the given environment. Accepts: `RAILS_ENV` (optional, default is "development").

Seeding is a bit different than Rails's built-in seeding, so I'll talk a little bit about that. Basically, you can still keep seeds in `db/seeds.rb` like before, but if you want to break them into separate files, you can put them in `seeds/`, and Kaplan will look for them there too. In fact, the seed files don't have to be Ruby, they can also be YAML or text files. So a YAML seed file would look like:

    people:
      -
        first_name: Joe
        last_name: Bloe
        likes: eating spaghetti, watching The Godfather
      -
        first_name: Jill
        last_name: Schmoe
        likes: biking, watching Family Guy

and a text file would look like (note it looks kind of like CSV, but not quite, because you can't quote fields):

    # first name, last name, likes
    Joe  Bloe  eating spaghetti, watching The Godfather
    Jill  Schmoe  biking, watching Family Guy

In addition, you can have environment-specific files. So if I have a directory structure that looks like:

    seeds/
      people.txt
      development/
        cars.rb
        venues.rb
      test/
        cars.rb
        car_types.yml

Then, when I run `rake kaplan:db:seed` in different environments, this is which tables get populated:

    +-------------+-------------------------+
    | Environment | Tables                  |
    +-------------+-------------------------+
    | development | people, cars, venues    |
    | production  | people                  |
    | test        | people, cars, car_types |
    +-------------+-------------------------+

## Author/License

Kaplan is by Elliot Winkler (<elliot.winkler@gmail.com>).

There isn't a license; you may do what you like with it, as long as I'm not held responsible.