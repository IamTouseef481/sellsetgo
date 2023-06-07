ebay_site_details = "#{:code.priv_dir(:sell_set_go_api)}/seeds/insert_ebay_site_details.exs"
hosts = "#{:code.priv_dir(:sell_set_go_api)}/seeds/insert_hosts.exs"
routes = "#{:code.priv_dir(:sell_set_go_api)}/seeds/insert_routes.exs"

if File.exists?(ebay_site_details) do
  Code.eval_file(ebay_site_details)
else
  IO.puts("File not found!")
end

if File.exists?(hosts) do
  Code.eval_file(hosts)
else
  IO.puts("File not found!")
end

if File.exists?(routes) do
  Code.eval_file(routes)
else
  IO.puts("File not found!")
end
