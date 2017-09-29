rproxies ![Ruby >=1.9.3](https://img.shields.io/badge/Ruby-%3E%3D1.9.3-green.svg) [![License](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/SValkanov/rproxies/blob/master/LICENSE.txt)
====

Kind of translation of [fetch-some-proxies](https://github.com/stamparm/fetch-some-proxies) by [stamparm](https://github.com/stamparm).
Simple Ruby script for fetching "some" (usable) proxies. It fetches (daily) list of public proxies and automatically finds in a quick manner those usable in that same moment.

Why should you use it? Well, if you've ever used free proxy lists around you'll know the pain of finding actually working proxies. This tool will automatically do the list fetching and proxy testing for you.

![fetch](https://user-images.githubusercontent.com/8790422/31039634-c7fc66e6-a587-11e7-8b7d-2132a3f078ac.png)

Requirements
----

Ruby version 1.9.3 or higher.

gem [parallel](https://github.com/grosser/parallel)

[Branch with no dependencies.](https://github.com/SValkanov/rproxies/tree/no_dependencies)
