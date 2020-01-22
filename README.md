# Beetlejuice

Data scraper for Bugsnag

![Beetlejuice holding a bug](http://img2.wikia.nocookie.net/__cb20121029232852/villains/images/thumb/1/1e/Beetlejuicecartoon.png/500px-Beetlejuicecartoon.png)

Bugsnag is a great tool, but it lacks the ability to export all events, this scraper is a work around this limitation.

## Setup
For the first time install dependencies and allow execution:
```
bundle
chmod u+x beetlejuice.rb
```


## Usage

To get a list of bug events, copy the full URL to the bug, and start Beetlejuice like so:

```
./beetlejuice.rb 'https://bugnsnag-url/please/note/the/quotes'
```

Make sure you put the url between quotes. Beetlejuice will scrape Bugsnag and output the results in `output.json`

For more options:
```
./beetlejuice.rb --help
```


