apa_glm<-function(object=NULL, observed=NULL, es="ges", correction="GG", op = "(", cp = ")"){

  ## Weiche:
  if ("aovlist" %in% class(object)){
    x<-lapply(summary(object),arrange_summary.aov)
    df<-do.call("rbind",x)
    df<-data.frame(df,row.names=1:nrow(df))
  } else

  if("summary.aov" %in% class(object)){
    df<-arrange_summary.aov(object)
  } else

  if("anova" %in% class(object)){
    df<-arrange_anova(object)
  } else

  if("aov" %in% class(object)){
    df<-arrange_aov(object)
  } else

  if("Anova.mlm" %in% class(object)){
    # copy from Henrik Singmann to handle his output objects
    x<-suppressWarnings(afex::univ(object))
    t.out <- x[["anova"]]
    if (correction[1] == "GG") {
      t.out[row.names(x[["sphericity.correction"]]), "num Df"] <- t.out[row.names(x[["sphericity.correction"]]), "num Df"] * x[["sphericity.correction"]][,"GG eps"]
      t.out[row.names(x[["sphericity.correction"]]), "den Df"] <- t.out[row.names(x[["sphericity.correction"]]), "den Df"] * x[["sphericity.correction"]][,"GG eps"]
      t.out[row.names(x[["sphericity.correction"]]), "Pr(>F)"] <- x[["sphericity.correction"]][,"Pr(>F[GG])"]
    } else {
      if (correction[1] == "HF") {
        if (any(x[["sphericity.correction"]][,"HF eps"] > 1)) warning("HF eps > 1 treated as 1")
        t.out[row.names(x[["sphericity.correction"]]), "num Df"] <- t.out[row.names(x[["sphericity.correction"]]), "num Df"] * pmin(1, x[["sphericity.correction"]][,"HF eps"])
        t.out[row.names(x[["sphericity.correction"]]), "den Df"] <- t.out[row.names(x[["sphericity.correction"]]), "den Df"] * pmin(1, x[["sphericity.correction"]][,"HF eps"])
        t.out[row.names(x[["sphericity.correction"]]), "Pr(>F)"] <- x[["sphericity.correction"]][,"Pr(>F[HF])"]
      } else {
        if (correction[1] == "none") {
          TRUE
        } else stop("None supported argument to correction.")
      }
    }
    df <- as.data.frame(t.out)
    # obtain positons of statistics in data.frame
    old<-c("SS","num Df","Error SS","den Df", "F", "Pr(>F)")
    nu<-c("sumsq","df","sumsq_err","df2","statistic","p.value")
    colnames(df)==old
    for (i in 1:length(old)){
      colnames(df)[colnames(df)==old[i]]<-nu[i]
    }
    df[["term"]]<-rownames(df)
    df<-data.frame(df,row.names=1:nrow(df))
  }   else stop("Non-supported object class")

  # from here on every class of input object is handled the same way
  x<-df

  # calculate generalized eta squared
  # This code is as copy from afex by Henrik Singmann who said that it is basically a copy from ezANOVA by Mike Lawrence
  if(!is.null(observed)){
    obs <- rep(FALSE,nrow(x))
    for(i in observed){
      if (!any(str_detect(rownames(x),str_c("\\<",i,"\\>")))) stop(str_c("Observed variable not in data: ", i))
      obs <- obs | str_detect(rownames(x),str_c("\\<",i,"\\>"))
    }
    obs_SSn1 <- sum(x$SS*obs)
    obs_SSn2 <- x$SS*obs
  }else{
    obs_SSn1 <- 0
    obs_SSn2 <- 0
  }
  x$ges <- x$sumsq/(x$sumsq+sum(unique(x$sumsq_err))+obs_SSn1-obs_SSn2)
  # calculate partial eta squared
  x$pes <- x$sumsq/(x$sumsq+x$sumsq_err)

  # rounding and filling with zeros
  x[,"statistic"]<-printnum(x[,"statistic"],digits=2,margin=2)
  x["p.value"]<-printp(x[,"p.value"])
  x[,c("df","df2")]<-round(x[,c("df","df2")],digits=2)
  x[,c("ges","pes")]<-printnum(x[,c("ges","pes")],digits=3,margin=2,gt1=FALSE)

  # add 'equals' where necessary
  eq<-(1:nrow(x))[!grepl(x[,"p.value"],pattern="<|>|=")]
  for (i in eq){
    x[,"p.value"][i]<-paste0("= ",x[,"p.value"][i])
  }

  # concatenate character strings
  x[["md.text"]]<-as.character(NA)

  for (i in 1:nrow(x)){
    x[["md.text"]][i]<-paste0("*F*", op, x[["df"]][i], ", ", x[["df2"]][i], cp, " = ", x[["statistic"]][i], ", *p* ", x[["p.value"]][i])
    if("ges" %in% es){
      x[["md.text"]][i]<-paste0(x[["md.text"]][i],", $\\eta^2_G$ = ", x[["ges"]][i])
    }
    if("pes" %in% es){
      x[["md.text"]][i]<-paste0(x[["md.text"]][i],", $\\eta^2_p$ = ", x[["pes"]][i])
    }
  }

  # return as named list
  values<-as.list(x[["md.text"]])
  names(values)<-x[["term"]]
  return(values)
}

## class 'anova'
arrange_anova<-function(anova){
  object<-as.data.frame(anova)
  x<-data.frame(array(NA,dim=c(nrow(object)-1,7)),row.names=NULL)
  colnames(x)<-c("term","sumsq","df","sumsq_err","df2","statistic","p.value")
  x[,c("sumsq","df","statistic","p.value")]<-object[-nrow(object),c("Sum Sq","Df","F value","Pr(>F)")]
  x[["sumsq_err"]]<-object[nrow(object),"Sum Sq"]
  x[["df2"]]<-object[nrow(object),"Df"]
  x[["term"]]<-rownames(object)[-nrow(object)]
  x
}

## class 'aov'
arrange_aov<-function(aov){
  x<-tidy(aov)
  x[["sumsq_err"]]<-x[nrow(x),"sumsq"]
  x[["df2"]]<-x[nrow(x),"df"]
  x<-x[-nrow(x),]
  x
}

## class 'summary.aov'
arrange_summary.aov<-function(aov){
  x<-arrange_aov(aov[[1]])
}


#load("~/Dropbox/Pudel/Pudel1/Daten/Daten_Pudel1.RData")
#library(afex)
#library(broom)
#library(papaja)
#object<-ez.glm(data=Daten.Gen,id="id",dv="korrekt.2nd",between=c("Material","Generierung","Reihenfolge"),within="Instruktion",fun.aggregate=mean,na.rm=TRUE,return="A")
#object<-ez.glm(data=Daten.Gen,id="id",dv="korrekt.2nd",between=c("Material","Generierung","Reihenfolge"),fun.aggregate=mean,na.rm=TRUE,return="lm")
#univ<-ez.glm(data=Daten.Gen,id="id",dv="korrekt.2nd",between=c("Material","Generierung","Reihenfolge"),within="Instruktion",fun.aggregate=mean,na.rm=TRUE,return="univ")
#object<-ez.glm(data=Daten.Gen,id="id",dv="korrekt.2nd",between=c("Material","Generierung","Reihenfolge"),within="Instruktion",fun.aggregate=mean,na.rm=TRUE,return="nice")
## Functions to arrange different classes of anova output
## class 'anova'
#class(object)

#object<-Anova(ez.glm(data=Daten.Gen,id="id",dv="korrekt.2nd",between=c("Material","Generierung","Reihenfolge"),fun.aggregate=mean,na.rm=TRUE,return="lm"),type=3)

