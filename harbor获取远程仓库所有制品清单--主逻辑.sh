harbor获取远程仓库所有制品清单
主逻辑：
1--API探活
URL
/ping
2--获取项目统计信息
URL
/statistics
字段total_project_count
主要获取其中所有项目的数量 total_project_count
用于下一步获取所有项目名称 因为项目太多 一次API查询只能查询一页 项目太多需要处理API查询分页
3--根据项目数量 遍历每一页项目 获取所有项目名称
URL
/projects?page=${i}&page_size=${PAGE_SIZE_DEFAULT}
4--遍历每一个项目下所有仓库前 先获取该项目下所有仓库数量 repo_count 便于下一步API分页查询所有仓库
URL
/projects/${PROJECT}/summary
字段repo_count
5--根据仓库数量 获取每个项目下所有仓库名称
URL
/projects/${PROJECT}/repositories?page=${i}&page_size=${PAGE_SIZE_DEFAULT}
字段name
6--遍历每一个仓库下所有制品前 先获取所有制品数量 artifact_count 便于下一步API分页查询所有制品digest
URL
projects/${PROJECT}/repositories/${REPO_IN_URL}
字段artifact_count
7--根据制品数量 获取当前项目当前仓库下所有制品digest列表
URL
/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts?page=${i}&page_size=${PAGE_SIZE_DEFAULT}
字段digest
8--遍历每个制品的references字段 如果为null表示单架构镜像 其他情况为多架构镜像
URL
/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts/${ARTIFACT_DIGEST_IN_URL}?page=1&page_size=100
字段references
9--根据当前项目 当前仓库 当前制品遍历每个子制品digest
URL
/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts/${ARTIFACT_DIGEST_IN_URL}?page=1&page_size=100
字段child_digest
10--最终得到所有制品列表  注意过滤处理 reference 的平台架构或平台OS为 unknown 的制品


原脚本有四层循环：
第一层遍历所有项目、第二层遍历每个项目下所有的仓库、第三层遍历每个仓库下所有制品、第四层便利每个制品下所有子制品
且：项目、仓库、制品、子制品是有分层依赖关系的，
只有知道项目名称，才能用项目名称的API查询该项目下所有仓库，
只有知道仓库名称，才能通过仓库名的API称查询该项目该仓库下所有制品digest，
只有知道制品digest，才能通过制品digest名称API查询所有子制品digest，
且：每一层API查询结果都有分页 需要注意的是 每次遍历项目、仓库、制品前都有API分页查询处理


获取harbor所有制品digest
第一层项目
第二层仓库
第三层制品digest
第四层子制品digest 如果镜像是多架构镜像那么就有第四层
示例：
├── bamboo
├── demo
├── library
│   ├── library/mario
│   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   ├── library/zhangdeshuai
│   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
│   │   │   ├── sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
