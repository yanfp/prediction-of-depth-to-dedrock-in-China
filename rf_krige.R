
library(gstat)
library(sp)
load(file = "D:/SCI data/data.RData")

R2 <- function(ret)
{
    return(1 - var(ret$measured - ret$predicted, na.rm = TRUE) / var(ret$measured - mean(ret$measured, na.rm = TRUE)))
}

RMSE <- function(ret)
{
    return(sqrt(mean((ret$measured - ret$predicted)^2, na.rm=TRUE)))
}

ME <- function(ret)
{
    return(mean(ret$measured - ret$predicted, na.rm=TRUE))
}

##################
#n_fold折交叉验证
##################
n_fold <- 7
samples_num <- nrow(DATA)
sub_num <- floor(samples_num/n_fold)
all_index <- 1:samples_num
sampled_index<-vector()
index_list<-list()
for(i in 1:n_fold)
{
    if(i == n_fold)
    {
        index_list <- c(index_list,list(all_index))
        break
    }
    sub_index <- sample(all_index, sub_num)
    index_list <- c(index_list, list(sub_index))
    sampled_index <- c(sampled_index, sub_index)
    all_index <- 1:samples_num
    all_index <- all_index[-sampled_index]
}

##用于保存测量值和预测值
y_pred <- data.frame(measured=NA, predicted=NA) 
y_pred <- y_pred[-1,]

##############################
#随机森林+克里金
##############################
library(randomForest)
load("D:/SCI data/rf.RData")
res <- rf$predicted - rf$y
res_spdf <- data.frame(LON = DATA$LON, LAT = DATA$LAT, RES = res)
coordinates(res_spdf) <- ~LON+LAT
#残差的半变异函数
RES_v <- variogram(RES ~ 1, res_spdf, width = 0.5)
plot(RES_v, main = "Variogram of Residuals(randomForest)")
RES_vgm <- vgm(psill = 2800, range = 5, nugget = 2300, model = "Sph")
res_fit_var <- fit.variogram(RES_v, RES_vgm)
plot(RES_v, model = res_fit_var)


y_pred <- data.frame(measured=NA, predicted=NA) 
y_pred <- y_pred[-1,]

for(j in 1:n_fold)
{
    #将数据分为训练集和验证集
    train_index <- vector()
    test_index <- index_list[[j]]
    for(k in (1:n_fold)[-j])
    {
        train_index <- c(train_index,index_list[[k]])  
    }
    
    train_data <- DATA[train_index, 4:col_num]
    test_data <- DATA[test_index, 4:col_num]
    test_points <- DATA[test_index, 2:3]
    coordinates(test_points) <- ~LON+LAT
    
    rf <- randomForest(x = train_data[, -1], 
                       y = train_data[, 1], 
                       ntree = 1000, 
                       ntry = 18)
    rf_pred <- predict(rf, newdata = test_data[, -1])
    # res <- rf$predicted - rf$y
    # krige_data <- data.frame(LON = DATA[train_index,2], 
    #                          LAT = DATA[train_index, 3], 
    #                          RES = res)
    # kg_model <- krige(RES~1, 
    #                   loc = ~LON+LAT, 
    #                   data = krige_data, 
    #                   newdata = test_points, 
    #                   model = res_fit_var)
    # rf_res <- kg_model@data$var1.pred
    pred = rf_pred
    y_pred <- rbind(y_pred, 
                    data.frame(measured=test_data[, 1], predicted=pred))
    print(j)
}
R2(y_pred)
RMSE(y_pred)
ME(y_pred)
