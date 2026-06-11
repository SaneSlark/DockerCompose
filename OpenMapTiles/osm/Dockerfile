FROM maven:3.9-eclipse-temurin-21 AS builder

RUN apt-get update && apt-get install -y git

RUN git clone --depth 1 --recurse-submodules https://github.com/openmaptiles/planetiler-openmaptiles.git /src

WORKDIR /src

# 修改 Building.java - 添加 name 字段
RUN sed -i '/setMinPixelSize(2)/a\        .setAttrWithMinzoom("name", element.source().getTag("name"), 14)\n        .setAttrWithMinzoom("name:zh", element.source().getTag("name:zh"), 14)' src/main/java/org/openmaptiles/layers/Building.java

# 修改 Landuse.java - 添加 name 字段  
RUN sed -i '/setAttr(Fields.CLASS, clazz)/a\        .setAttrWithMinzoom("name", element.source().getTag("name"), 13)\n        .setAttrWithMinzoom("name:zh", element.source().getTag("name:zh"), 13)' src/main/java/org/openmaptiles/layers/Landuse.java

# 编译
RUN mvn clean package -DskipTests -q

FROM eclipse-temurin:21-jre

# 复制带依赖的 JAR（包含 Main-Class）
COPY --from=builder /src/target/planetiler-openmaptiles-3.16.1-SNAPSHOT-with-deps.jar /app/planetiler.jar

WORKDIR /data

ENTRYPOINT ["java", "-jar", "/app/planetiler.jar"]