library(ggplot2)

out <- ggplot(data = mtcars, mapping = aes(x = disp, y = mpg)) + 
	geom_smooth() + 
	geom_point()

ggsave(here::here("fig1.pdf"), out)
