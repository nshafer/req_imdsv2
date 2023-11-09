VERSION := $(shell mix eval 'Mix.Project.config()[:version] |> IO.puts')

.PHONY:
tag:
	git tag -f "v$(VERSION)"
	git push origin "v$(VERSION)"

.PHONY:
publish: tag
	mix hex.publish
