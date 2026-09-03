# frozen_string_literal: true

# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = 'https://salato.app'

SitemapGenerator::Sitemap.create do

    add "/", changefreq: "daily", priority: 1.0

    add "/events", changefreq: "daily", priority: 0.9

    add "#about", changefreq: "monthly", priority: 0.5

    add "#contact", changefreq: "monthly", priority: 0.5

    Event.find_each do |event|
      add event_path(event),
          lastmod: event.updated_at,
          changefreq: "daily",
          priority: 0.8
    end
end
