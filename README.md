# Refreshing

This is a Rails engine that adds language server support to Rails applications.
It is a very very extremely POC code, so please don't ask for any assistance!!

I have it configured in Vim like this:

```
if filereadable(".livecode")
  au User lsp_setup
        \ call lsp#register_server({
        \      'name': 'cool-lsp',
        \      'cmd': ["nc", "localhost", "2000"],
        \      'allowlist': ['ruby', 'eruby'],
        \ })
endif
```

The target app just needs to mount the engine like so:

```ruby
Rails.application.routes.draw do
  mount Refreshing::Engine => "/refreshing"
end
```

AFAIK this only works with Falcon in threaded mode:

```
bundle exec falcon --threaded
```
