rproxies ![Ruby >=1.9.3](https://img.shields.io/badge/Ruby-%3E%3D1.9.3-green.svg) [![License](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/SValkanov/rproxies/blob/master/LICENSE.txt)
====

Kind of translation of [fetch-some-proxies](https://github.com/stamparm/fetch-some-proxies) by [stamparm](https://github.com/stamparm)
Simple Ruby script for fetching "some" (usable) proxies. It fetches list of public proxies (from [here](https://hidester.com)) and automatically finds in a quick manner those usable in that same moment.

Why should you use it? Well, if you've ever used free proxy lists around you'll know the pain of finding actually working proxies. This tool will automatically do the list fetching and proxy testing for you.



Requirements
----

gem [parallel](https://github.com/grosser/parallel)
Ruby version 1.9.3 or higher.
In future there will be branch with no dependencies.
