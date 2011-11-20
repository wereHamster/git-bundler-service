
all:
	./node_modules/.bin/coffee -c app.coffee
	./node_modules/.bin/stylus -c public/style.styl
