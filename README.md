# tongji_baidu

由于Medportal网站无法使用Google统计功能，所以我们使用百度统计来替代Google统计完成对本体访问的统计任务。具体的实现过程可参看docs文件夹中的“使用Baidu统计替换Google统计.doc”文档。除了参考文档外，我们还提供了源代码文件_baidu_tongji.html.haml和ontology_analytics.rb。



## 1. _baidu_tongji.html.haml

_baidu_tongji.html.haml文件存在于bioportal_web_ui/app/views/application/目录下。该文件中的代码应被添加到Medportal网站页面的<head></head>标签中，用来完成对受访页面的记录。其访问结果将被记录到百度统计系统中。



## 2. ontology_analytics.rb

ontology_analytics.rb文件存在于ncbo_cron/lib/ncbo_cron/目录下。该程序通过使用百度统计API从百度统计系统中获取报告数据，对数据处理后，将结果记录到redis缓存中。

注意：请指定该文件如下代码段中的username,password,token和site_id。
```
	raw = {
          "header": {
               "username": "yourusername",
               "password": "yourpassword",
               "token": "yourtoken",
               "account_type": 1
           },
           "body": {
               "site_id": "yoursiteid",
               "start_date": "#{start_date}",
               "end_date": "#{end_date}",
               "metrics": "pv_count",
               "method": "visit/toppage/a",
               "start_index": "#{start_index}",
               "max_results": "#{max_results}"
           }
    }  
```

## 3. medportal version description

Medportal基于NCBO BioPortal构建，核心组件及其版本号为

- ncbo_cron(v5.8.0)
- ontologies_api(v5.8.0)
- bioportal_web_ui(v5.6.0)

ontology_analytics.rb是基于ncbo_cron(v5.8.0)修改而来支持百度访问统计的。如果您使用的不是5.8版本的ncbo_cron，那么请您根据实际情况自行修改ontology_analytics.rb文件。