/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
package org.apache.stratos.metadataservice.services;

import org.apache.commons.configuration.XMLConfiguration;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.stratos.metadataservice.annotation.AuthorizationAction;
import org.apache.stratos.metadataservice.definition.CartridgeMetaData;
import org.apache.stratos.metadataservice.definition.NewProperty;
import org.apache.stratos.metadataservice.exception.RestAPIException;
import org.apache.stratos.metadataservice.registry.DataRegistryFactory;
import org.apache.stratos.metadataservice.registry.DataStore;
import org.apache.stratos.metadataservice.util.ConfUtil;
import org.wso2.carbon.registry.api.RegistryException;

import javax.servlet.http.HttpServletRequest;
import javax.ws.rs.*;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.UriInfo;
import java.net.URI;
import java.util.List;

@Path("/")
public class MetaDataAdmin {
    @Context
    UriInfo uriInfo;

    private static Log log = LogFactory.getLog(MetaDataAdmin.class);
    @Context
    HttpServletRequest httpServletRequest;


    private DataStore registry;

    /**
     * Meta data admin configuration loading
     */
    public MetaDataAdmin(){
        XMLConfiguration conf = ConfUtil.getInstance(null).getConfiguration();
        String DEFAULT_REG_TYPE = "carbon";
        String registryType =  conf.getString("metadataservice.govenanceregistrytype", DEFAULT_REG_TYPE);
        registry = DataRegistryFactory.getDataRegistryFactory(registryType);
    }

    @POST
    @Path("/cartridge/metadata/{applicationname}/{cartridgetype}")
    @Produces("application/json")
    @Consumes("application/json")
    @AuthorizationAction("/permission/protected/manage/monitor/tenants")
    public Response addCartridgeMetaDataDetails(@PathParam("applicationname") String applicationName,
                                                @PathParam("cartridgetype") String cartridgeType,
                                                CartridgeMetaData cartridgeMetaData) throws RestAPIException {


        URI url = uriInfo.getAbsolutePathBuilder().path(applicationName + "/" + cartridgeType).build();
        try {
            registry.addCartridgeMetaDataDetails(applicationName, cartridgeType, cartridgeMetaData);
        } catch (Exception err) {
            log.error("Error occurred while adding meta data details ", err);
        }

        return Response.created(url).build();

    }

    @GET
    @Path("/cartridge/metadata/{applicationname}/{cartridgetype}")
    @Produces("application/json")
    @Consumes("application/json")
    @AuthorizationAction("/permission/protected/manage/monitor/tenants")
    public Response getCartridgeMetaDataDetails(@PathParam("applicationname") String applicationName,
                                                @PathParam("cartridgetype") String cartridgeType) throws RestAPIException {

        String result = null;
        try {
            result = registry.getCartridgeMetaDataDetails(applicationName, cartridgeType);
        } catch (Exception err) {
            log.error("Error occurred while adding meta data details ", err);
        }
        Response.ResponseBuilder rb;
        if (result == null) {
            rb = Response.status(Response.Status.NOT_FOUND);
        } else {
            rb = Response.ok().entity(result);
        }
        return rb.build();

    }

    @GET
    @Path("/application/{application_id}/cluster/{cluster_id}/properties")
    @Produces("application/json")
    @Consumes("application/json")
    @AuthorizationAction("/permission/protected/manage/monitor/tenants")
    public Response getClusterProperties(@PathParam("application_id") String applicationId, @PathParam("cluster_id") String clusterId){

        List<NewProperty> properties;
        NewProperty[] propertiesArr = null;
        try {
            properties = registry
                    .getPropertiesOfCluster(applicationId, clusterId);
            if (properties != null) {
                propertiesArr = new NewProperty[properties.size()];
                propertiesArr = properties.toArray(propertiesArr);
            }
        } catch (Exception e) {
            log.error("Error occurred while getting properties ", e);
        }

        Response.ResponseBuilder rb;
        if (propertiesArr == null) {
            rb = Response.status(Response.Status.NOT_FOUND);
        } else {
            rb = Response.ok().entity(propertiesArr);
        }
        return rb.build();
    }

    @GET
    @Path("/application/{application_id}/cluster/{cluster_id}/property/{property_name}")
    @Produces("application/json")
    @Consumes("application/json")
    @AuthorizationAction("/permission/protected/manage/monitor/tenants")

    public Response getClusterProperty(@PathParam("application_id") String applicationId, @PathParam("cluster_id") String clusterId, @PathParam("property_name") String propertyName){
        List<NewProperty> properties;


        NewProperty property = null;

        try {
            properties = registry
                    .getPropertiesOfCluster(applicationId, clusterId);
            if (properties == null) {
                return Response.status(Response.Status.NOT_FOUND).build();
            }
            for (NewProperty p : properties) {
                if (propertyName.equals(p.getKey())) {
                    property = p;
                    break;
                }
            }
        } catch (Exception e) {
            log.error("Error occurred while getting property ", e);
        }

        Response.ResponseBuilder rb;
        if (property == null) {
            rb = Response.status(Response.Status.NOT_FOUND);
        } else {
            rb = Response.ok().entity(property);
        }
        return rb.build();
    }

    @POST
    @Path("application/{application_id}/cluster/{cluster_id}/property")
    @Produces("application/json")
    @Consumes("application/json")
    @AuthorizationAction("/permission/protected/manage/monitor/tenants")
    public Response addPropertyToACluster(@PathParam("application_id") String applicationId, @PathParam("cluster_id") String clusterId, NewProperty property)
            throws RestAPIException {

        URI url =  uriInfo.getAbsolutePathBuilder().path(applicationId + "/" + clusterId + "/" + property.getKey()).build();

        try {
            registry.addPropertyToCluster(applicationId, clusterId, property);
        } catch (RegistryException e) {
            log.error("Error occurred while adding property", e);
        }

        return Response.created(url).build();

    }

    @POST
    @Path("application/{application_id}/cluster/{cluster_id}/properties")
    @Produces("application/json")
    @Consumes("application/json")
    @AuthorizationAction("/permission/protected/manage/monitor/tenants")
    public Response addPropertiesToACluster(@PathParam("application_id") String applicationId, @PathParam("cluster_id") String clusterId, NewProperty[] properties)
            throws RestAPIException {
        URI url = uriInfo.getAbsolutePathBuilder().path(applicationId + "/" + clusterId).build();

        try {
            registry.addPropertiesToCluster(applicationId, clusterId, properties);
        } catch (Exception e) {
            log.error("Error occurred while adding properties ", e);
        }


        return Response.created(url).build();
    }


}
