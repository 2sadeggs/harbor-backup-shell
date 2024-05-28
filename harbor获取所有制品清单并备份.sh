#!/bin/bash
set -exo pipefail



################################ 备份目录文件--手动处理部分 ################################################################

# 备份磁盘挂载目录
BACKUP_DISK_MOUNT_POINT="/data"

# 备份家目录--备份家目录需手动创建
BACKUP_HOME="${BACKUP_DISK_MOUNT_POINT}/backup"
# 手动创建备份家目录命令
# [ ! -d "${BACKUP_HOME}" ] && mkdir -p "${BACKUP_HOME}"

# 备份脚本目录--备份脚本目录需手动创建
BACKUP_SHELL_DIR="${BACKUP_HOME}/shell"
# 手动创建备份脚本目录命令
# [ ! -d "${BACKUP_SHELL_DIR}" ] && mkdir -p "${BACKUP_SHELL_DIR}"

# 备份脚本文件--备份脚本文件需手动创建
BACKUP_SHELL="${BACKUP_SHELL_DIR}/harbor-backup.sh"
# 为保证shell here documents正常工作 请使用空格代替tab键缩进
# tab键在here documents里的开头会被删除 直接顶格 破坏格式 真是恼烦
# cat <<"EOSH" > "${BACKUP_SHELL}"
# paste shellscript here
# EOSH

################################ 备份目录文件--手动处理部分 ################################################################



################################ 备份数据和日志 ################################################################
# 备份数据目录
BACKUP_DATA_DIR="${BACKUP_HOME}/data"
# 脚本执行时若备份数据目录不存在则创建
[ -d "${BACKUP_DATA_DIR}" ] || mkdir -p "${BACKUP_DATA_DIR}"

# 备份日志目录
# 脚本执行时若备份日志目录不存在则创建
BACKUP_LOG_DIR="${BACKUP_HOME}/log"
[ -d "${BACKUP_LOG_DIR}" ] || mkdir -p "${BACKUP_LOG_DIR}"

# 备份日志文件
BACKUP_LOG="${BACKUP_LOG_DIR}/harbor-backup-$(date '+%Y%m%d-%H%M%S-%N').log"
echo "日志文件"
echo "${BACKUP_LOG}"

# 备份镜像清单
IMAGE_LIST="${BACKUP_LOG_DIR}/harbor-images-$(date '+%Y%m%d-%H%M%S-%N').txt"
echo "备份镜像清单"
echo "${IMAGE_LIST}"

# 备份镜像清单--多架构镜像
IMAGE_MULTI_ARCH_LIST="${BACKUP_LOG_DIR}/harbor-images-multi-arch-$(date '+%Y%m%d-%H%M%S-%N').txt"
echo "备份镜像--多架构镜像清单"
echo "${IMAGE_MULTI_ARCH_LIST}"

# 备份镜像本地文件
IMAGE_LOCALFILE_LIST="${BACKUP_LOG_DIR}/harbor-localfiles-$(date '+%Y%m%d-%H%M%S-%N').txt"
echo "备份镜像本地文件"
echo "${IMAGE_LOCALFILE_LIST}"

# 备份镜像本地文件--带完整路径
IMAGE_LOCALFILE_LIST_FULLPATH="${BACKUP_LOG_DIR}/harbor-localfiles-fullpath-$(date '+%Y%m%d-%H%M%S-%N').txt"
echo "备份镜像本地文件--带完整路径"
echo "${IMAGE_LOCALFILE_LIST_FULLPATH}"

# 备份镜像制品树状图
ARTIFACT_TREE="${BACKUP_LOG_DIR}/harbor-artifact-tree-$(date '+%Y%m%d-%H%M%S-%N').txt"
echo "备份镜像制品树状图"
echo "${ARTIFACT_TREE}"


################################ 备份数据和日志 ################################################################





echo "$(date '+%Y%m%d-%H%M%S-%N') start>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"


# 日志重定向到日志文件
exec 3>&1 4>&2 >> "${BACKUP_LOG}" 2>&1

# 定义脚本运行的开始时间
START_TIME=$(date +%s)



################################ 历史备份数据清理 ##########################################################

# 备份文件保留天数
MAINTAIN_DAYS_DATA=1
MAINTAIN_DAYS_LOG=7

# 清理${MAINTAIN_DAYS}天前的备份
# 清理数据目录
find "${BACKUP_DATA_DIR}" -name "*.tar" -type f -mtime +"${MAINTAIN_DAYS_DATA}" -print -delete
# 清理日志目录
# find -o 选项 也就是逻辑或 或者tar结尾 或者log结尾 或者csv结尾 或者txt结尾 -a 逻辑与
find "${BACKUP_LOG_DIR}" \( -name "*.csv" -o -name "*.log" -o -name "*.txt" -o -name "*.json" \) -a -type f -a -mtime +${MAINTAIN_DAYS_LOG} -print -exec rm -f "{}" \;

################################ 历史备份数据清理 ##########################################################




############################### harbor基础信息 ##########################################################

# harbor IP address or hostname
HARBOR_ADDRESS="harbor.demo.com"
# harbor http schema
SCHEME="https"

# AUTH
# 改用AUTH认证 读取本地docker的config.json 避免脚本里出现明文用户名密码
# AUTH=$(jq -r ".auths.\"$HARBOR_ADDRESS\".auth" ~/.docker/config.json | base64 -d)  # WARN: on OSX base64 -D not -d
AUTH=$(jq -r ".auths.\"$HARBOR_ADDRESS\".auth | @base64d" ~/.docker/config.json)

# api json 请求头
HEADER_JSON="accept: application/json"

# api plain 请求头
HEADER_PLAIN="accept: text/plain"

# Harbor API 2.0
# [ Base URL: harbor.demo.com/api/v2.0 ]
BASE_URL="${SCHEME}://${HARBOR_ADDRESS}/api/v2.0"

# API请求中每页请求默认值
# PAGE_SIZE_DEFAULT=10
# 临时改为5便于分页debug调试
# PAGE_SIZE_DEFAULT=5
# 临时改为100 减少分页 便于节省API请求次数
PAGE_SIZE_DEFAULT=100

# API请求中每页请求最大值
PAGE_SIZE_MAX=100

############################### harbor基础信息 ##########################################################




################### harbor api ping-pong ######################################################################
# GET
# ​/ping
# Ping Harbor to check if it's alive.
# curl -X GET "https://harbor.demo.com/api/v2.0/ping" -H "accept: text/plain"
# Pong
PONG=$(curl -k -u "${AUTH}" -H "${HEADER_PLAIN}" -X GET "${BASE_URL}/ping")
if [[ "${PONG}" == "Pong" ]]; then
	echo "harbor is alive"
else
	echo "harbor api ping failed and exit"
	exit 0
fi
################### harbor api ping-pong ######################################################################





############################################ 获取所有镜像清单 ##################################################

# harbor统计信息
# GET
# ​/statistics
# Get projects number and repositories number relevant to the user
# curl -X GET "https://harbor.demo.com/api/v2.0/statistics" -H "accept: application/json"

# harbor统计信息json文件
STATUTICS_JSON="${BACKUP_LOG_DIR}/statistics-$(date '+%Y%m%d-%H%M%S-%N').json"
curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/statistics" | jq '.' > ${STATUTICS_JSON}

echo "harbor统计信息"
# 所有项目
TOTAL_PROJECT_COUNT=$(jq -r '.total_project_count' "${STATUTICS_JSON}")
# 私有项目
PRIVATE_PROJECT_COUNT=$(jq -r '.private_project_count' "${STATUTICS_JSON}")
# 共有项目
PUBLIC_PROJECT_COUNT=$(jq -r '.public_project_count' "${STATUTICS_JSON}")
# 所有仓库信息
TOTAL_REPO_COUNT=$(jq -r '.total_repo_count' "${STATUTICS_JSON}")
# 私有仓库数量
PRIVATE_REPO_COUNT=$(jq -r '.private_repo_count' "${STATUTICS_JSON}")
# 共有仓库数量
PUBLIC_REPO_COUNT=$(jq -r '.public_repo_count' "${STATUTICS_JSON}")

echo "所有项目数量：${TOTAL_PROJECT_COUNT}  其中私有项目个数：${PRIVATE_PROJECT_COUNT}  共有项目个数：${PUBLIC_PROJECT_COUNT}"
echo "所有仓库数量：${TOTAL_REPO_COUNT}  其中私有仓库个数：${PRIVATE_REPO_COUNT}  共有仓库个数：${PUBLIC_REPO_COUNT}"

# 判断没有项目的情况 如果没有项目直接退出
if [[ $((TOTAL_PROJECT_COUNT)) == 0 || "${TOTAL_PROJECT_COUNT}" == "null" ]]; then
	echo "harbor has no project and exit this job"
	exit 0
else
	echo "harbor backup job start"
fi


# 项目列表信息
# GET
# ​/projects
# List projects
# curl -X GET "https://harbor.demo.com/api/v2.0/projects?page=1&page_size=10&with_detail=true" -H "accept: application/json"

# 定义保存projects信息的json文件
PROJECTS_JSON="${BACKUP_LOG_DIR}/projects-$(date '+%Y%m%d-%H%M%S-%N').json"

# 单次查询最大值100个项目json文件 调试验证用 可注释
# curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects?page=1&page_size=${PAGE_SIZE_MAX}&with_detail=true" | jq '.' > ${PROJECTS_JSON}


# 不管是否满足分页条件 直接全部分页 分页公式如下
# pageCount = (totalCount + pageSize - 1) / pageSize
# 计算项目分页页数
PROJECT_PAGE_COUNT=$(( ("$TOTAL_PROJECT_COUNT" + "$PAGE_SIZE_DEFAULT" - 1)/"$PAGE_SIZE_DEFAULT" ))
# 遍历每一页并将结果保存到对应json文件
for ((i=1; i<=${PROJECT_PAGE_COUNT}; i++)); do
	echo "当前页${i}"
	# 项目分页json数据
	curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects?page=${i}&page_size=${PAGE_SIZE_DEFAULT}" | jq '.' > ${PROJECTS_JSON}_page_${i}.json
	# 项目列表 列表追加
	# PROJECT_LIST+=( $(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects?page=${i}&page_size=${PAGE_SIZE_DEFAULT}" | jq -r '.[].name') )
	PROJECT_LIST+=( $(jq -r '.[].name' "${PROJECTS_JSON}_page_${i}.json") )
	echo "项目列表"
	echo "${PROJECT_LIST[@]}"
done
# jq 如果不加 -r 参数那么获取的 PROJECT 有双引号
# PROJECT_LIST 从json转换过来默认是个带空格的字符串 外边加个小括号转换为数组

echo "所有项目列表"
echo "${PROJECT_LIST[@]}"

# 遍历每个项目 以及每个项目下的仓库 以及每个仓库下面的制品 以及每个制品下的子制品-也就是多架构镜像
for PROJECT in "${PROJECT_LIST[@]}"; do
	echo "当前项目"
	echo "${PROJECT}"
	echo "├── ${PROJECT}" >> ${ARTIFACT_TREE}
	# 获取当前项目概要 包含该项目下的仓库数量
	# curl -X GET "https://harbor.demo.com/api/v2.0/projects/op/summary" -H "accept: application/json" | jq -r '.repo_count'
	# 该项目下的仓库数量
	REPO_COUNT=$(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/summary" | jq -r '.repo_count')
	if [ "${REPO_COUNT}" == "null" ]; then
		# REPO_COUNT为null 说明是该项目空仓库 跳出本次项目循环 进行下一个项目
		echo "当前项目没有仓库"
		REPO_COUNT=0
		echo "当前项目${PROJECT}所有仓库数量${REPO_COUNT}"
		continue
	fi
	echo "当前项目${PROJECT}所有仓库数量${REPO_COUNT}"
	# 定义保存repositories信息的json文件
	REPOS_JSON="${BACKUP_LOG_DIR}/project-${PROJECT}-repositories-$(date '+%Y%m%d-%H%M%S-%N').json"

	# 单次查询最大值100个仓库json文件 调试验证用 可注释
	# curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}?page=1&page_size=${PAGE_SIZE_MAX}" | jq '.' > ${REPOS_JSON}

	# 获取当前项目下所有仓库列表 不管是否满足分页条件 全部分页
	# 计算仓库分页页数
	REPO_PAGE_COUNT=$(( ("$REPO_COUNT" + "$PAGE_SIZE_DEFAULT" - 1)/"$PAGE_SIZE_DEFAULT" ))

	# 遍历每一页并将结果保存到对应json文件
	for ((i=1; i<=${REPO_PAGE_COUNT}; i++)); do
		echo "当前页${i}"
		# 仓库分页json数据
		curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories?page=${i}&page_size=${PAGE_SIZE_DEFAULT}" | jq '.' > ${REPOS_JSON}_page_${i}.json
		# 仓库列表，名称包含项目名称
		# REPO_LIST+=( $(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories?page=${i}&page_size=${PAGE_SIZE_DEFAULT}" | jq -r '.[].name') )
		REPO_LIST+=( $(jq -r '.[].name' "${REPOS_JSON}_page_${i}.json") )
		echo "仓库列表"
		echo "${REPO_LIST[@]}"
	done
	echo "当前项目${PROJECT}所有仓库列表${REPO_LIST[@]}"

	for REPO in "${REPO_LIST[@]}"; do
		echo "当前仓库"
		echo "${REPO}"
		echo "│   ├── ${REPO}" >> ${ARTIFACT_TREE}
		# 将REPO里的PROJECT前缀删除 以便符合API接口调用规范
		# library/mario_runtime ==> mario_runtime
		# 其中library为项目名称
		REPO_WITHOUT_PROJECT_PREFIX=${REPO/#$PROJECT\/}
		echo "仓库名去除项目前缀"
		echo "${REPO_WITHOUT_PROJECT_PREFIX}"
		# 处理仓库名里有多个斜线的情况 例如op/dpage/pgadmin4
		# The name of the repository. If it contains slash, encode it with URL encoding. e.g. a/b -> a%252Fb
		# op/dpage/pgadmin4 ==> dpage/pgadmin4 ==> dpage%252Fpgadmin4  dpage%252Fpgadmin4
		REPO_IN_URL=${REPO_WITHOUT_PROJECT_PREFIX//\//%252F}
		echo "URL里的仓库"
		echo "${REPO_IN_URL}"
		# 获取当前仓库制品数量
		ARTIFACT_COUNT=$(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories/${REPO_IN_URL}" | jq -r '.artifact_count')
		if [ "${ARTIFACT_COUNT}" == "null" ]; then
			echo "获取当前仓库数量出错"
			# 仓库名称里有斜线且在URL里查询时没转换就会出现这种情况 例如op/dpage/pgadmin4
			ARTIFACT_COUNT=0
			# 跳出本次仓库循环 进入下一个仓库
			continue
		fi
		echo "当前项目${PROJECT}当前仓库${REPO}所有制品数量${ARTIFACT_COUNT}"
		# 定义保存artifacts信息的json文件
		ARTIFACTS_JSON="${BACKUP_LOG_DIR}/project-${PROJECT}-repositories-${REPO_IN_URL}-$(date '+%Y%m%d-%H%M%S-%N').json"

		# 单次查询最大值100个制品json文件 调试验证用 可注释
		# curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts?page=1&page_size=${PAGE_SIZE_MAX}" | jq -r '.' > ${ARTIFACTS_JSON}

		# 计算制品数量分页页数
		ARTIFACT_PAGE_COUNT=$(( ("$ARTIFACT_COUNT" + "$PAGE_SIZE_DEFAULT" - 1)/"$PAGE_SIZE_DEFAULT" ))
		for ((i=1; i<=${ARTIFACT_PAGE_COUNT}; i++)); do
			echo "当前页${i}"
			# 制品分页json数据
			curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts?page=${i}&page_size=${PAGE_SIZE_DEFAULT}" | jq -r '.' > ${ARTIFACTS_JSON}_page_${i}.json
			# 制品签名列表
			# ARTIFACT_DIGEST_LIST+=( $(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts?page=${i}&page_size=${PAGE_SIZE_DEFAULT}" | jq -r '.[].digest') )
			ARTIFACT_DIGEST_LIST+=( $(jq -r '.[].digest' "${ARTIFACTS_JSON}_page_${i}.json") )
			echo "制品签名列表"
			echo "${ARTIFACT_DIGEST_LIST[@]}"
		done
		echo "当前项目${PROJECT}当前仓库${REPO}所有制品列表${ARTIFACT_DIGEST_LIST[@]}"
		for ARTIFACT_DIGEST in "${ARTIFACT_DIGEST_LIST[@]}"; do
			echo "当前制品签名"
			echo "${ARTIFACT_DIGEST}"
			echo "│   │   ├── ${ARTIFACT_DIGEST}" >> ${ARTIFACT_TREE}
			# 将冒号":" 替换为URL里识别的"%3A" 然后请求
			# sha256:9322e3edcde04a0d25460e58cf406ccb04f6c6ef1c026771b3d621d95ec80bca
			# sha256%3A9322e3edcde04a0d25460e58cf406ccb04f6c6ef1c026771b3d621d95ec80bca
			ARTIFACT_DIGEST_IN_URL=${ARTIFACT_DIGEST//:/%3A}
			echo "URL里的制品签名"
			echo "${ARTIFACT_DIGEST_IN_URL}"
			ARTIFACT_REFERENCES=( $(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts/${ARTIFACT_DIGEST_IN_URL}?page=1&page_size=100" | jq -r '.references') )
			echo "制品引用列表"
			echo "${ARTIFACT_REFERENCES[@]}"
			echo "制品引用列表长度"
			echo "${#ARTIFACT_REFERENCES[@]}"
			# 判断ARTIFACT_REFERENCES是否为null
			# 如果为null 那么说明该镜像是单CPU架构型 ARCH一般为amd64
			# 如果不为空 那么说明该镜像是多CPU架构类型 需要遍历ARTIFACT_REFERENCES中的CHILD_DIGEST
			if [ "${ARTIFACT_REFERENCES}" == "null" ]; then
				# 镜像完整URI示例
				# harbor.demo.com/library/mario_runtime@sha256:4a064fb7a957c8a7150e951007f7b7fb3dddda0a25571f8159d2946197e291bd
				echo "${HARBOR_ADDRESS}/${REPO}@${ARTIFACT_DIGEST}" >> ${IMAGE_LIST}
				echo "当前项目${PROJECT}当前仓库${REPO}当前制品签名${ARTIFACT_DIGEST}"
			else
				# ARTIFACT_REFERENCES 不空的话说明是多架构镜像 需要遍历 child_digest
				echo "ARTIFACT_REFERENCES 不为空"
				# 记录多架构镜像digest 一遍debug调试和验证
				echo "${HARBOR_ADDRESS}/${REPO}@${ARTIFACT_DIGEST}" >> ${IMAGE_MULTI_ARCH_LIST}
				# CHILD_DIGEST_LIST=( $(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts/${ARTIFACT_DIGEST_IN_URL}?page=1&page_size=100" | jq -r '.references' | jq -r '.[].child_digest') )
				# 改为jq内部管道
				CHILD_DIGEST_LIST=( $(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts/${ARTIFACT_DIGEST_IN_URL}?page=1&page_size=100" | jq -r '.references | .[].child_digest') )
				echo "CHILD_DIGEST列表"
				echo "${CHILD_DIGEST_LIST[@]}"
				for CHILD_DIGEST in "${CHILD_DIGEST_LIST[@]}"; do
					echo "当前CHILD_DIGEST"
					echo "${CHILD_DIGEST}"
					# CHILD_DIGEST 替换 ARTIFACT_DIGEST 也就是不同架构镜像的digest 而不是该镜像tag的digest
					# 两者的区别在于 同一tag下可能是多个架构的镜像 也就是有多个镜像digest 备份时需要全部备份
					# 如果不指定不同架构的镜像digest 那么默认只拉取和备份机器架构相同的镜像tag的digest
					# 比如amd64的主机 如果按照tag为最后一级的方式遍历的话 那么默认只能拉取到amd64架构的镜像备份 拉取不到arm或其他架构的镜像
					# ***如果出现unknown的架构那么跳过
					# 将冒号":" 替换为URL里识别的"%3A" 然后请求
					# sha256:9322e3edcde04a0d25460e58cf406ccb04f6c6ef1c026771b3d621d95ec80bca
					# sha256%3A9322e3edcde04a0d25460e58cf406ccb04f6c6ef1c026771b3d621d95ec80bca
					CHILD_DIGEST_IN_URL=${CHILD_DIGEST//:/%3A}
					echo "URL里的子制品签名"
					echo "${CHILD_DIGEST_IN_URL}"
					ARCH=$(curl -k -u "${AUTH}" -H "${HEADER_JSON}" -X GET "${BASE_URL}/projects/${PROJECT}/repositories/${REPO_IN_URL}/artifacts/${CHILD_DIGEST_IN_URL}?page=1&page_size=100" | jq -r '.extra_attrs.architecture')
					if [ "${ARCH}" == "unknown" ]; then
						echo "不识别的架构"
						echo "${HARBOR_ADDRESS}/${REPO}@${CHILD_DIGEST}"
						continue
					fi
					echo "${HARBOR_ADDRESS}/${REPO}@${CHILD_DIGEST}" >> ${IMAGE_LIST}
					echo "当前项目${PROJECT}当前仓库${REPO}当前制品签名${ARTIFACT_DIGEST}当前子制品签名${CHILD_DIGEST}"
					echo "|----${HARBOR_ADDRESS}/${REPO}@${CHILD_DIGEST}" >> ${IMAGE_MULTI_ARCH_LIST}
					echo "│   │   │   ├── ${CHILD_DIGEST}" >> ${ARTIFACT_TREE}
				done
				echo "列表CHILD_DIGEST_LIST本次遍历完成${CHILD_DIGEST_LIST[@]}"
				echo "将列表置位空"
				CHILD_DIGEST_LIST=()
			fi
		done
		echo "列表ARTIFACT_DIGEST_LIST本次遍历完成${ARTIFACT_DIGEST_LIST[@]}"
		echo "将列表置位空"
		ARTIFACT_DIGEST_LIST=()
	done
	echo "列表REPO_LIST本次遍历完成${REPO_LIST[@]}"
	echo "将列表置位空${REPO_LIST[@]}"
	REPO_LIST=()
done

# 循环结束前将列表置位空 
# 如果列表不为空的话 下次遍历列表再追加列表的话会发生追加上次的列表 造成多余数据
# 当然PROJECT_LIST只被遍历一次 不会引起上述问题
echo "列表PROJECT_LIST本次遍历完成${PROJECT_LIST[@]}"
echo "将列表置位空${PROJECT_LIST[@]}"
PROJECT_LIST=()

############################################ 获取所有镜像清单 ##################################################



# 下载镜像清单并打包备份
# 私有仓库拉取镜像需要确保登录 默认读取~/.docker/config.json文件登录
docker login ${HARBOR_ADDRESS}

##################################################### 并发控制部分 #################################################

# trap 捕捉到信号 2表示ctrl+c
trap "exec 6>&-;exec 6<&-;exit 0" 2

# 创建管道名称
TMP_FIFOFILE="/tmp/$$.fifo"
# 新建一个FIFO类型的文件
[ -e ${TMP_FIFOFILE} ] || mkfifo ${TMP_FIFOFILE}

# 将FD6指向FIFO类型
exec 6<>${TMP_FIFOFILE}
# 将创建的管道文件清除,关联后的文件描述符拥有管道文件的所有特性,所以这时候管道文件可以删除，我们留下文件描述符来用就可以了
rm ${TMP_FIFOFILE}

# 指定并发个数
#CONCURRENT_NUM=100
CONCURRENT_NUM=1

# 根据线程总数量设置令牌个数
# 事实上就是在fd6中放置了$CONCURRENT_NUM个回车符
for ((i=0;i<${CONCURRENT_NUM};i++)); do
	echo
done >&6

# 遍历镜像清单 然后逐个下载到本地备份成文件
while read ARTIFACT; do
	# 一个read -u6命令执行一次，就从FD6中减去一个回车符，然后向下执行
	# 当FD6中没有回车符时，就停止，从而实现线程数量控制
	read -u6
	{
		echo "读取当前制品"
		echo "${ARTIFACT}"
		# set -e
		# {
		# 镜像完整URI示例
		# harbor.demo.com/library/mario_runtime@sha256:4a064fb7a957c8a7150e951007f7b7fb3dddda0a25571f8159d2946197e291bd
		# 本地文件名有限制 期望转换成如下格式
		# harbor.demo.com_library_mario_runtime___sha256___4a064fb7a957c8a7150e951007f7b7fb3dddda0a25571f8159d2946197e291bd
		# 首先 以冒号作为分隔 删除前半部分 保留后半部分的签名值
		# 匹配删除前缀 最长匹配删除 也就是保留最后一个冒号后边的字符串
		IMAGE_DIGEST=${ARTIFACT##*:}
		# 然后最后一个冒号前边的部分 略过sha256 直接到@符号部分 删除@符号后边部分
		# 匹配删除后缀 最长匹配删除 也就是把最前边一个@符号后边的删除 前边的作为URI
		URI=${ARTIFACT%@*}
		# 将URI中的斜线替换为下划线 全部替换 斜线"/"转义为"\/"
		IMAGE_NAME=${URI//\//___}
		# 组合生成本地镜像备份文件完整URI
		IMAGE_LOCALFILE_FULLNAME="${IMAGE_NAME}___sha256___${IMAGE_DIGEST}___$(date '+%Y%m%d-%H%M%S-%N').tar"
		# 将本地文件名保存到文件列表
		echo "${IMAGE_LOCALFILE_FULLNAME}" >> ${IMAGE_LOCALFILE_LIST}
		# debug验证测试用 节约docker save的时间
		# touch "${BACKUP_DATA_DIR}/${IMAGE_LOCALFILE_FULLNAME}"
		docker pull "${ARTIFACT}" && docker save "${ARTIFACT}" -o "${BACKUP_DATA_DIR}/${IMAGE_LOCALFILE_FULLNAME}"
		echo "${BACKUP_DATA_DIR}/${IMAGE_LOCALFILE_FULLNAME}" >> ${IMAGE_LOCALFILE_LIST_FULLPATH}
		# }
		# set +e
		echo >&6
		# 当进程结束以后，再向FD6中加上一个回车符，即补上了read -u6减去的那个
	}&
done < ${IMAGE_LIST}

# 等待后台进程完成
wait



##################################################### 并发控制部分 #################################################


# 定义脚本运行的结束时间
END_TIME=$(date +%s)
# 输出脚本运行时间
echo "job runs time $(("END_TIME"-"START_TIME"))"

# 关闭FD6
exec 6<&-
exec 6>&-

# 恢复FD3 FD4
exec 1>&3 2>&4

echo "$(date '+%Y%m%d-%H%M%S-%N') end<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "脚本运行时间"
# echo "time:`expr ${END_TIME} - ${START_TIME}`"
echo "time: $(("END_TIME"-"START_TIME"))"


