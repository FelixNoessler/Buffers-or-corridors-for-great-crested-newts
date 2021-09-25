
setwd('~/Desktop/newt')

library(tidyverse)
init_pop <- read_csv('initial_population.csv', skip=6)

# maybe there are some runs which go extinct..
max_step <- 
  init_pop %>%
  rename(start_pop = `number-of-startind`,
         out_pop = `count turtles`,
         step = `[step]`,
         run_id = `[run number]`) %>% 
  group_by(start_pop, scenario, run_id) %>%
  summarise(max(step))


text_init_pop <- init_pop %>%
  rename(start_pop = `number-of-startind`,
         out_pop = `count turtles`,
         step = `[step]`,
         run_id = `[run number]`) %>% 
  group_by(start_pop, scenario) %>%
  filter(step == 100) %>%
  summarise(n = n())


init_pop %>%
  rename(start_pop = `number-of-startind`,
         out_pop = `count turtles`,
         step = `[step]`,
         run_id = `[run number]`) %>%
  mutate(start_pop = as.factor(start_pop),
         scenario = as.factor(scenario)) %>%
  filter(step == 100) %>%
  ggplot() +
  geom_boxplot(aes(x =start_pop, y=out_pop, fill=scenario))+
  #geom_jitter(aes(x =start_pop, y=out_pop, col=scenario), width = 0.1)+
  labs(x = 'Start population', y = 'Population size after 100 years \n (if survived)')
ggsave('init_pop.svg')


capacity <- read_csv('capacity.csv', skip=6)

capacity %>%
  rename( out_pop = `total-newts`) %>%
  mutate(capacity = as.factor(capacity),
         scenario = as.factor(scenario)) %>%
  ggplot() +
  geom_boxplot(aes(x =capacity, y=out_pop, fill=scenario))+
  #geom_jitter(aes(x =start_pop, y=out_pop, col=scenario), width = 0.1)+
  labs(x = 'Capacity per pond', y = 'Population size after 100 years')
ggsave('capacity.svg')
  

movement_energy <- read_csv('energy.csv', skip=6)

movement_energy %>%
  rename(out_pop = `total-newts`,
         energy = `movement-energy`) %>%
  mutate(energy = as.factor(energy),
         scenario = as.factor(scenario)) %>%
  ggplot() +
  geom_boxplot(aes(x =energy, y=out_pop, fill=scenario))+
  #geom_jitter(aes(x =start_pop, y=out_pop, col=scenario), width = 0.1)+
  labs(x = 'Movement energy', y = 'Population size after 100 years')
ggsave('movement_energy.svg')
  