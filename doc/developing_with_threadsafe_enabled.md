# Threadsafe Kochiku

Author: Rob Olson

### Intro

Since Kochiku is a good place to experiment with different things, I enabled `config.threadsafe!` in `config/environments/production.rb`.

### How does it work

First, it's good to understand what that flag does. Aaron Patterson wrote a good explaination in this blog post: http://tenderlovemaking.com/2012/06/18/removing-config-threadsafe.html.

So as a summary, it forces all code loading to be done when the application boots and it removes the Rack::Lock from the middleware stack.

For even more advanced information about autoloading, see José Valim's post [Eager loading for the greater good](http://blog.plataformatec.com.br/2012/08/eager-loading-for-greater-good/).

### How to adapt for Threadsafe mode

It's easy to do, but also easy to forget about. All of the classes in `lib/` and `app/uploaders/` need to be explicitly required in the files that they are used. To start, I've taken a Java-esk route of adding a require to the top of every file that uses a class in one of those folders. If you add a new file to `lib/` or `app/uploaders/` you will need to do this too.

If anyone feels like this approach is too error prone, we could change to an initializer that lists out all of the files in lib that need to be loaded. This way new files will only need to required once and in one place.
