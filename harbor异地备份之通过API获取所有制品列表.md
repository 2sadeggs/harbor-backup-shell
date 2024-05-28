#### harbor异地备份之通过API获取所有制品列表

* Ping Harbor to check if it's alive.

![image-20230905141903929](harbor异地备份之通过API获取所有制品列表.assets\image-20230905141903929.png)

* Health check API
  再详细的说返回的事harbor各个组件的健康情况

​	![image-20230905133913569](harbor异地备份之通过API获取所有制品列表.assets\image-20230905133913569.png)

* Get projects number and repositories number relevant to the user

![image-20230905134022675](harbor异地备份之通过API获取所有制品列表.assets\image-20230905134022675.png)

* List projects

![image-20230905134301237](harbor异地备份之通过API获取所有制品列表.assets\image-20230905134301237.png)

* List repositories

![image-20230905134451162](harbor异地备份之通过API获取所有制品列表.assets\image-20230905134451162.png)

* List artifacts
  同下图
* Get the specific artifact

![image-20230905134542127](harbor异地备份之通过API获取所有制品列表.assets\image-20230905134542127.png)

* 总结
  harbor API 文档给的接口足够丰富，说明足够详细，不再用中文重复了，说一下利用API获取所有制品的思路：
  * 唯一标识：使用制品签名而不是制品标签
    每个制品的签名都是不同的，但是标签有可能相同
    同一标签下可能有多架构镜像，多架构镜像公用一个tag，但是不同平台拉取时获取到不同架构的镜像
    另一个问题是一个制品可能有多个标签，即该镜像有多个tag，一个稳定版本tag：v10，一个滚动更新版本tag：v10.xxx
    综上排除镜像标签tag作为唯一标识，采用制品签名ARTIFACT_DIGEST作为唯一表示，制品签名ARTIFACT_DIGEST是不重复的
  * 首先利用/ping接口判断接口是否可用，然后进行下一步；health接口返回每个组件的状态
  * 然后/statistics接口 Get projects number and repositories number relevant to the user
    注意是对应用户的项目数和仓库数，所以要想所有制品需要是所有项目和仓库的管理员，admin用户通常能满足条件，但是也需要仔细验证
  * 接着到达/projects接口，获取所有项目，注意默认有请求限制，也就是每页请求最多100条，默认10条，通过统计信息里获得的项目数计算分页，然后遍历每一页获取到所有项目列表
  * 然后遍历所有项目列表
  * 然后到达/projects/{project_name}/repositories接口，获取每个项目下所有的仓库，这里的接口也有数量限制，所以同样需要获取每个项目下有多少个仓库，这是另一个接口，如下
  * 每个项目下仓库数量接口/projects/{project_name_or_id}/summary，通过该接口获取每个项目下所有仓库数量，然后分页，然后遍历每一页获取该项目下的所有仓库，注意改接口依赖项目名称或项目ID，所以需要先知道项目项目名称或ID，代码中就需要将改接口放在遍历每一个项目循环的里边，只有这样才知道当前项目的名称或ID
  * 第一层遍历所有项目，第二层获取当前项目下所有仓库列表，接下来到达第三层，当前项目、当前仓库下所有制品列表
  * 第三层制品，接口/projects/{project_name}/repositories/{repository_name}/artifacts
    首层项目，二层仓库，第三层制品，需要获取该项目该仓库下所有的制品，与上述接口相同的是该接口也有数量限制，通过上层仓库接口获取该项目该仓库下所有制品数量，然后计算分页，然后遍历每一页获取所有制品
  * 第四层，子制品，也就是多架构镜像，比如arm版镜像，关键字ARTIFACT_REFERENCES字段，如果该字段为null，那么就是单架构镜像，一般为amd64架构，如果不为空，那么表示有子制品，需要遍历子制品CHILD_DIGEST，如此四层下来即可遍历所有制品签名ARTIFACT_DIGEST
  * 最后注意制品的reference平台架构或平台OS，如果为unknown，那么这个制品一般是docker buildx产生的，需要排除，否则下载的时候有可能报错