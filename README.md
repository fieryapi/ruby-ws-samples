## Sample Ruby Program To Demonstrate How To Receive Fiery Events

Setup the bundler in `src` directory with `bundle install`, modify `fiery_events.rb` in the configuration section to connect to the Fiery then execute the script with `bundle exec ruby fiery_events.rb`

The sample program runs three scenarios:

  * Receive only Fiery status change events
  * Receive only job is printing? events
  * Receive only job is printing? events in batch mode
 
If you want to move to the next scenario, simply press `enter` key

**Note** Always use secure connection (HTTPS) when connecting to Fiery API in production.