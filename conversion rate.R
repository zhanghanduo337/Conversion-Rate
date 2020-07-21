rm(list = ls())
library(dplyr)
library(ggplot2)
library(pROC)
library("readxl")
library("tidyverse")
library(randomForest)
library(gbm)

############################################################################################################
### import data

df = read.csv('/Users/zhanghanduo/Desktop/data/conversion_data.csv')

#############################exploratory data analysis

View(df)
attach(df)
mean(df$converted) #average conversion rate 0.03224898
summary(df)#age and total_pages_visited seem to have outliers 

conv_country = df %>% 
  group_by(country) %>%
  summarise(avg_conv = mean(converted)) %>%
  arrange(desc(avg_conv))
conv_country #China is significantly lower than others

conv_source = df %>% 
  group_by(source) %>%
  summarise(avg_sour = mean(converted)) %>%
  arrange(desc(avg_sour))
conv_source

conv_country_age = df %>% 
    group_by(country) %>%
       summarise(avg_age = mean(age)) %>%
       arrange(desc(avg_age))
conv_country_age

conv_country_new = df %>% 
  group_by(country) %>%
  summarise(avg_new = mean(new_user)) %>%
  arrange(desc(avg_new))
conv_country_new

conv_country_source = df %>% 
  group_by(country,source) %>%
  summarise(avg_conv = mean(converted)) %>%
  arrange(desc(avg_conv))
conv_country_source

plot(df$age, main = 'age_distribution', ylab = 'age',xlab = 'index')
identify(df$age,n = 2,labels = age)


plot(df$total_pages_visited, main = 'pagevist_distribution', ylab = 'pages',xlab = 'index')
identify(df$total_pages_visited,n = 2,labels = total_pages_visited)

###############################get rid of the outliers 

df = df[df$age<100,]
df = df[-258074,]
df = df[-302290,]
dim(df) #316196 * 6

##############################Random Forest

library(randomForest)
set.seed(1)
train = sample(1:nrow(df),nrow(df)/2)
rf.conv = randomForest(converted~.,data = df,subset = train,mtry = 3,importance = TRUE)

conv_pred_rf = predict(rf.conv,df[-train,])

mean((conv_pred_rf-df[-train,]$converted))^2 #test MSE 1.076016e-08

varImpPlot(rf.conv) 
#variable importance plot: total_pages_visited >> new_user > country > age > source

rf_pred = rep(0,nrow(df[-train,]))
rf_pred[conv_pred_rf>0.5]=1
table(rf_pred,df[-train,]$converted)
mean(rf_pred==df[-train,]$converted) #error rate 1.4%

#############################random forest without total_pages_visited

rf.conv_2 = randomForest(converted~.,data = df[,-5],subset = train,mtry = 3,
                         importance = TRUE)
conv_pred_rf_2 = predict(rf.conv_2,df[-train,])

mean((conv_pred_rf_2-df[-train,]$converted))^2 #test MSE 1.703655e-10

varImpPlot(rf.conv_2) #importance: new_user  > country > age > source

rf_pred_2 = rep(0,nrow(df[-train,]))
rf_pred_2[conv_pred_rf_2>0.2]=1 
#cutoff point should be adjusted according to company's interests, i.e. 
# which one of type I error and type II error is more serious?
table(rf_pred_2,df[-train,]$converted)
mean(rf_pred_2==df[-train,]$converted) #error rate: 4%
op = par(mfrow=c(1,1))
partialPlot(rf_pred_2,df[train,],country,1)

#############################Boosted trees


set.seed(1)

boosted.conv = gbm(converted~.,data = df[train,], n.trees  = 5000, distribution = 'bernoulli',
                   interaction.depth = 4, shrinkage = 0.1, verbose = T)
conv_pred_boosted = predict(boosted.conv,df[-train,],n.trees = 5000)
boosted_pred= rep(0,nrow(df[-train,]))
boosted_pred[conv_pred_boosted>0.5]=1
table(boosted_pred,df[-train,]$converted)
mean(boosted_pred==df[-train,]$converted) # error rate is 1.5%
mean((conv_pred_boosted-df[-train,]$converted))^2 # test MSE: 45.7

plot(boosted.conv, i = 'total_pages_visited')
# partial dependence plot for 'total_pages_visited'
# Before 20 pages of visits, the more page visits the higher effect on conversion rate
# Once hits are more than 20, the effect remains roughly the same, but still pretty high
# That aligns with the common sense where people usually go through a lot of pages 
# if they are willingly to buy something from the internet.
plot(boosted.conv, i = 'age')
# partial dependence plot for 'age'
# Users in their early 20s and 30s have relatively high marginal effect on conversion 
# rate, whereas users roughly between 50 and 57 have the lowest effect on conversion rate
plot(boosted.conv, i = 'country')
# partial dependence plot for 'country'
# Users in Germany seems to have the highest marginal effect on conversion rate 
# among all the countries, whereas China has the lowest, which is significantly
# lower than other countries. More data ought to be collected to find out what's going
# on in China, maybe it's the local competitors, or government policy, or commercials 
# and sources channels. However, market in Germany should be where we put most our
# focus on. Specifially, we should be more focus on the ads, seo source in Germany, despite
# of the fact that source is seemingly less important than other features. Additionally,
# we should try to attract more young, new uses in Germany who, according to the result,
# can result in high conversion rate.