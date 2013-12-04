/* Copyright (C) 2013 BMW Group
 * Author: Manfred Bathelt (manfred.bathelt@bmw.de)
 * Author: Juergen Gehring (juergen.gehring@bmw.de)
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
package org.genivi.commonapi.dbus.generator

import java.util.HashMap
import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FAttribute
import org.franca.core.franca.FBroadcast
import org.franca.core.franca.FInterface
import org.franca.core.franca.FMethod
import org.franca.core.franca.FModelElement
import org.genivi.commonapi.core.generator.FTypeGenerator
import org.genivi.commonapi.core.generator.FrancaGeneratorExtensions
import org.genivi.commonapi.dbus.deployment.DeploymentInterfacePropertyAccessor

class FInterfaceDBusStubAdapterGenerator {
    @Inject private extension FrancaGeneratorExtensions
    @Inject private extension FrancaDBusGeneratorExtensions

    def generateDBusStubAdapter(FInterface fInterface, IFileSystemAccess fileSystemAccess, DeploymentInterfacePropertyAccessor deploymentAccessor, IResource modelid) {
        fileSystemAccess.generateFile(fInterface.dbusStubAdapterHeaderPath, fInterface.generateDBusStubAdapterHeader(modelid))
        fileSystemAccess.generateFile(fInterface.dbusStubAdapterSourcePath, fInterface.generateDBusStubAdapterSource(deploymentAccessor, modelid))
    }

    def private generateDBusStubAdapterHeader(FInterface fInterface, IResource modelid) '''
        «generateCommonApiLicenseHeader(fInterface, modelid)»
        «FTypeGenerator::generateComments(fInterface, false)»
        #ifndef «fInterface.defineName»_DBUS_STUB_ADAPTER_H_
        #define «fInterface.defineName»_DBUS_STUB_ADAPTER_H_

        #include <«fInterface.stubHeaderPath»>
        «IF fInterface.base != null»
        #include <«fInterface.base.dbusStubAdapterHeaderPath»>
        «ENDIF»

        #if !defined (COMMONAPI_INTERNAL_COMPILATION)
        #define COMMONAPI_INTERNAL_COMPILATION
        #endif

        #include <CommonAPI/DBus/DBusStubAdapterHelper.h>
        #include <CommonAPI/DBus/DBusStubAdapter.h>
        #include <CommonAPI/DBus/DBusFactory.h>
        #include <CommonAPI/DBus/DBusServicePublisher.h>

        #undef COMMONAPI_INTERNAL_COMPILATION

        «fInterface.model.generateNamespaceBeginDeclaration»

        typedef CommonAPI::DBus::DBusStubAdapterHelper<«fInterface.stubClassName»> «fInterface.dbusStubAdapterHelperClassName»;

        class «fInterface.dbusStubAdapterClassNameInternal»: public «fInterface.stubAdapterClassName», public «fInterface.dbusStubAdapterHelperClassName»«IF fInterface.base != null», public «fInterface.base.dbusStubAdapterClassNameInternal»«ENDIF» {
         public:
            «fInterface.dbusStubAdapterClassNameInternal»(
                    const std::shared_ptr<CommonAPI::DBus::DBusFactory>& factory,
                    const std::string& commonApiAddress,
                    const std::string& dbusInterfaceName,
                    const std::string& dbusBusName,
                    const std::string& dbusObjectPath,
                    const std::shared_ptr<CommonAPI::DBus::DBusProxyConnection>& dbusConnection,
                    const std::shared_ptr<CommonAPI::StubBase>& stub);

            ~«fInterface.dbusStubAdapterClassNameInternal»();

            «FOR attribute : fInterface.attributes»
                «IF attribute.isObservable»
                    «FTypeGenerator::generateComments(attribute, false)»
                    void «attribute.stubAdapterClassFireChangedMethodName»(const «attribute.getTypeName(fInterface.model)»& value);
                «ENDIF»
            «ENDFOR»

            «FOR broadcast: fInterface.broadcasts»
                «FTypeGenerator::generateComments(broadcast, false)»
                «IF !broadcast.selective.nullOrEmpty»
                    void «broadcast.stubAdapterClassFireSelectiveMethodName»(«generateFireSelectiveSignatur(broadcast, fInterface)»);
                    void «broadcast.stubAdapterClassSendSelectiveMethodName»(«generateSendSelectiveSignatur(broadcast, fInterface, true)»);
                    void «broadcast.subscribeSelectiveMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId, bool& success);
                    void «broadcast.unsubscribeSelectiveMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId);
                    std::shared_ptr<CommonAPI::ClientIdList> const «broadcast.stubAdapterClassSubscribersMethodName»();
                «ELSE»
                    void «broadcast.stubAdapterClassFireEventMethodName»(«broadcast.outArgs.map['const ' + getTypeName(fInterface.model) + '& ' + elementName].join(', ')»);
                «ENDIF»
            «ENDFOR»

            «FOR managed: fInterface.managedInterfaces»
                «managed.stubRegisterManagedMethod»;
                bool «managed.stubDeregisterManagedName»(const std::string&);
                std::set<std::string>& «managed.stubManagedSetGetterName»();
            «ENDFOR»

            const «fInterface.dbusStubAdapterHelperClassName»::StubDispatcherTable& getStubDispatcherTable();

            void deactivateManagedInstances();

            «IF fInterface.base != null»
            virtual const std::string getAddress() const {
                return DBusStubAdapter::getAddress();
            }

            virtual const std::string& getDomain() const {
                return DBusStubAdapter::getDomain();
            }

            virtual const std::string& getServiceId() const {
                return DBusStubAdapter::getServiceId();
            }

            virtual const std::string& getInstanceId() const {
                return DBusStubAdapter::getInstanceId();
            }

            virtual void init(std::shared_ptr<DBusStubAdapter> instance) {
                return DBusStubAdapter::init(instance);
            }

            virtual void deinit() {
                return DBusStubAdapter::deinit();
            }

            virtual bool onInterfaceDBusMessage(const CommonAPI::DBus::DBusMessage& dbusMessage) {
                return «fInterface.dbusStubAdapterHelperClassName»::onInterfaceDBusMessage(dbusMessage);
            }
            «ENDIF»

         protected:
            virtual const char* getMethodsDBusIntrospectionXmlData() const;
            
          private:
            «FOR managed: fInterface.managedInterfaces»
                std::set<std::string> «managed.stubManagedSetName»;
            «ENDFOR»
            «fInterface.dbusStubAdapterHelperClassName»::StubDispatcherTable stubDispatcherTable_;
        };

        class «fInterface.dbusStubAdapterClassName»: public «fInterface.dbusStubAdapterClassNameInternal», public std::enable_shared_from_this<«fInterface.dbusStubAdapterClassName»> {
        public:
            «fInterface.dbusStubAdapterClassName»(
                                 const std::shared_ptr<CommonAPI::DBus::DBusFactory>& factory,
                                 const std::string& commonApiAddress,
                                 const std::string& dbusInterfaceName,
                                 const std::string& dbusBusName,
                                 const std::string& dbusObjectPath,
                                 const std::shared_ptr<CommonAPI::DBus::DBusProxyConnection>& dbusConnection,
                                 const std::shared_ptr<CommonAPI::StubBase>& stub) :
                    CommonAPI::DBus::DBusStubAdapter(
                                    factory,
                                    commonApiAddress,
                                    dbusInterfaceName,
                                    dbusBusName,
                                    dbusObjectPath,
                                    dbusConnection,
                                    «IF !fInterface.managedInterfaces.nullOrEmpty»true«ELSE»false«ENDIF»),
                    «fInterface.dbusStubAdapterClassNameInternal»(
                                    factory,
                                    commonApiAddress,
                                    dbusInterfaceName,
                                    dbusBusName,
                                    dbusObjectPath,
                                    dbusConnection,
                                    stub) { }
        };

        «fInterface.model.generateNamespaceEndDeclaration»

        #endif // «fInterface.defineName»_DBUS_STUB_ADAPTER_H_
    '''

    def private generateDBusStubAdapterSource(FInterface fInterface, DeploymentInterfacePropertyAccessor deploymentAccessor, IResource modelid) '''
        «generateCommonApiLicenseHeader(fInterface, modelid)»
        #include "«fInterface.dbusStubAdapterHeaderFile»"
        #include <«fInterface.headerPath»>

        «fInterface.model.generateNamespaceBeginDeclaration»

        std::shared_ptr<CommonAPI::DBus::DBusStubAdapter> create«fInterface.dbusStubAdapterClassName»(
                           const std::shared_ptr<CommonAPI::DBus::DBusFactory>& factory,
                           const std::string& commonApiAddress,
                           const std::string& interfaceName,
                           const std::string& busName,
                           const std::string& objectPath,
                           const std::shared_ptr<CommonAPI::DBus::DBusProxyConnection>& dbusProxyConnection,
                           const std::shared_ptr<CommonAPI::StubBase>& stubBase) {
            return std::make_shared<«fInterface.dbusStubAdapterClassName»>(factory, commonApiAddress, interfaceName, busName, objectPath, dbusProxyConnection, stubBase);
        }

        __attribute__((constructor)) void register«fInterface.dbusStubAdapterClassName»(void) {
            CommonAPI::DBus::DBusFactory::registerAdapterFactoryMethod(«fInterface.elementName»::getInterfaceId(),
                                                                       &create«fInterface.dbusStubAdapterClassName»);
        }



        «fInterface.dbusStubAdapterClassNameInternal»::~«fInterface.dbusStubAdapterClassNameInternal»() {
            deactivateManagedInstances();
            «fInterface.dbusStubAdapterHelperClassName»::deinit();
        }

        void «fInterface.dbusStubAdapterClassNameInternal»::deactivateManagedInstances() {
            «FOR managed : fInterface.managedInterfaces»
                for(std::set<std::string>::iterator iter = «managed.stubManagedSetName».begin();
                        iter != «managed.stubManagedSetName».end(); ++iter) {
                    «managed.stubDeregisterManagedName»(*iter);
                }
            «ENDFOR»
        }

        const char* «fInterface.dbusStubAdapterClassNameInternal»::getMethodsDBusIntrospectionXmlData() const {
            static const std::string introspectionData =
                «IF fInterface.base != null»
                    std::string(«fInterface.base.dbusStubAdapterClassNameInternal»::getMethodsDBusIntrospectionXmlData()) +
                «ELSE»
                    "<method name=\"getInterfaceVersion\">\n"
                        "<arg name=\"value\" type=\"uu\" direction=\"out\" />"
                    "</method>\n"
                «ENDIF»
                «FOR attribute : fInterface.attributes»
                    "<method name=\"«attribute.dbusGetMethodName»\">\n"
                        "<arg name=\"value\" type=\"«attribute.dbusSignature(deploymentAccessor)»\" direction=\"out\" />"
                    "</method>\n"
                    «IF !attribute.isReadonly»
                        "<method name=\"«attribute.dbusSetMethodName»\">\n"
                            "<arg name=\"requestedValue\" type=\"«attribute.dbusSignature(deploymentAccessor)»\" direction=\"in\" />\n"
                            "<arg name=\"setValue\" type=\"«attribute.dbusSignature(deploymentAccessor)»\" direction=\"out\" />\n"
                        "</method>\n"
                    «ENDIF»
                    «IF attribute.isObservable»
                        "<signal name=\"«attribute.dbusSignalName»\">\n"
                            "<arg name=\"changedValue\" type=\"«attribute.dbusSignature(deploymentAccessor)»\" />\n"
                        "</signal>\n"
                    «ENDIF»
                «ENDFOR»
                «FOR broadcast : fInterface.broadcasts»
                    «FTypeGenerator::generateComments(broadcast, false)»
                    "<signal name=\"«broadcast.elementName»\">\n"
                        «FOR outArg : broadcast.outArgs»
                            "<arg name=\"«outArg.elementName»\" type=\"«outArg.getTypeDbusSignature(deploymentAccessor)»\" />\n"
                        «ENDFOR»
                    "</signal>\n"
                «ENDFOR»
                «FOR method : fInterface.methods»
                    «FTypeGenerator::generateComments(method, false)»
                    "<method name=\"«method.elementName»\">\n"
                        «FOR inArg : method.inArgs»
                            "<arg name=\"«inArg.elementName»\" type=\"«inArg.getTypeDbusSignature(deploymentAccessor)»\" direction=\"in\" />\n"
                        «ENDFOR»
                        «IF method.hasError»
                            "<arg name=\"methodError\" type=\"«method.dbusErrorSignature(deploymentAccessor)»\" direction=\"out\" />\n"
                        «ENDIF»
                        «FOR outArg : method.outArgs»
                            "<arg name=\"«outArg.elementName»\" type=\"«outArg.getTypeDbusSignature(deploymentAccessor)»\" direction=\"out\" />\n"
                        «ENDFOR»
                    "</method>\n"
                «ENDFOR»

                «IF fInterface.attributes.empty && fInterface.broadcasts.empty && fInterface.methods.empty»
                    ""
                «ENDIF»
            ;
            return introspectionData.c_str();
        }

        static CommonAPI::DBus::DBusGetAttributeStubDispatcher<
                «fInterface.stubClassName»,
                CommonAPI::Version
                > get«fInterface.elementName»InterfaceVersionStubDispatcher(&«fInterface.stubClassName»::getInterfaceVersion, "uu");

        «FOR attribute : fInterface.attributes»
            «FTypeGenerator::generateComments(attribute, false)»
            static CommonAPI::DBus::DBusGetAttributeStubDispatcher<
                    «fInterface.stubClassName»,
                    «attribute.getTypeName(fInterface.model)»
                    > «attribute.dbusGetStubDispatcherVariable»(&«fInterface.stubClassName»::«attribute.stubClassGetMethodName», "«attribute.dbusSignature(deploymentAccessor)»");
            «IF !attribute.isReadonly»
                static CommonAPI::DBus::DBusSet«IF attribute.observable»Observable«ENDIF»AttributeStubDispatcher<
                        «fInterface.stubClassName»,
                        «attribute.getTypeName(fInterface.model)»
                        > «attribute.dbusSetStubDispatcherVariable»(
                                &«fInterface.stubClassName»::«attribute.stubClassGetMethodName»,
                                &«fInterface.stubRemoteEventClassName»::«attribute.stubRemoteEventClassSetMethodName»,
                                &«fInterface.stubRemoteEventClassName»::«attribute.stubRemoteEventClassChangedMethodName»,
                                «IF attribute.observable»&«fInterface.stubAdapterClassName»::«attribute.stubAdapterClassFireChangedMethodName»,«ENDIF»
                                "«attribute.dbusSignature(deploymentAccessor)»");
            «ENDIF»

        «ENDFOR»

        «var counterMap = new HashMap<String, Integer>()»
        «var methodnumberMap = new HashMap<FMethod, Integer>()»
        «FOR method : fInterface.methods»
            «FTypeGenerator::generateComments(method, false)»
            «IF !method.isFireAndForget»
                static CommonAPI::DBus::DBusMethodWithReplyStubDispatcher<
                    «fInterface.stubClassName»,
                    std::tuple<«method.allInTypes»>,
                    std::tuple<«method.allOutTypes»>
                    «IF !(counterMap.containsKey(method.dbusStubDispatcherVariable))»
                        «{counterMap.put(method.dbusStubDispatcherVariable, 0);  methodnumberMap.put(method, 0);""}»
                        > «method.dbusStubDispatcherVariable»(&«fInterface.stubClassName + "::" + method.elementName», "«method.dbusOutSignature(deploymentAccessor)»");
                    «ELSE»
                        «{counterMap.put(method.dbusStubDispatcherVariable, counterMap.get(method.dbusStubDispatcherVariable) + 1);  methodnumberMap.put(method, counterMap.get(method.dbusStubDispatcherVariable));""}»
                        > «method.dbusStubDispatcherVariable»«Integer::toString(counterMap.get(method.dbusStubDispatcherVariable))»(&«fInterface.stubClassName + "::" + method.elementName», "«method.dbusOutSignature(deploymentAccessor)»");
                    «ENDIF»
            «ELSE»
                static CommonAPI::DBus::DBusMethodStubDispatcher<
                    «fInterface.stubClassName»,
                    std::tuple<«method.allInTypes»>
                    «IF !(counterMap.containsKey(method.dbusStubDispatcherVariable))»
                        «{counterMap.put(method.dbusStubDispatcherVariable, 0); methodnumberMap.put(method, 0);""}»
                        > «method.dbusStubDispatcherVariable»(&«fInterface.stubClassName + "::" + method.elementName»);
                    «ELSE»
                        «{counterMap.put(method.dbusStubDispatcherVariable, counterMap.get(method.dbusStubDispatcherVariable) + 1);  methodnumberMap.put(method, counterMap.get(method.dbusStubDispatcherVariable));""}»
                        > «method.dbusStubDispatcherVariable»«Integer::toString(counterMap.get(method.dbusStubDispatcherVariable))»(&«fInterface.stubClassName + "::" + method.elementName»);
                    «ENDIF»
            «ENDIF»
        «ENDFOR»

        «FOR attribute : fInterface.attributes»
            «FTypeGenerator::generateComments(attribute, false)»
            «IF attribute.isObservable»
                void «fInterface.dbusStubAdapterClassNameInternal»::«attribute.stubAdapterClassFireChangedMethodName»(const «attribute.getTypeName(fInterface.model)»& value) {
                    CommonAPI::DBus::DBusStubSignalHelper<CommonAPI::DBus::DBusSerializableArguments<«attribute.getTypeName(fInterface.model)»>>
                        ::sendSignal(
                            *this,
                            "«attribute.dbusSignalName»",
                            "«attribute.dbusSignature(deploymentAccessor)»",
                            value
                    );
                }
            «ENDIF»
        «ENDFOR»

        «FOR broadcast: fInterface.broadcasts»
            «FTypeGenerator::generateComments(broadcast, false)»
            «IF !broadcast.selective.nullOrEmpty»
                static CommonAPI::DBus::DBusMethodWithReplyAdapterDispatcher<
                    «fInterface.stubClassName»,
                    «fInterface.stubAdapterClassName»,
                    std::tuple<>,
                    std::tuple<bool>
                    > «broadcast.dbusStubDispatcherVariableSubscribe»(&«fInterface.stubAdapterClassName + "::" + broadcast.subscribeSelectiveMethodName», "b");

                static CommonAPI::DBus::DBusMethodWithReplyAdapterDispatcher<
                    «fInterface.stubClassName»,
                    «fInterface.stubAdapterClassName»,
                    std::tuple<>,
                    std::tuple<>
                    > «broadcast.dbusStubDispatcherVariableUnsubscribe»(&«fInterface.stubAdapterClassName + "::" + broadcast.unsubscribeSelectiveMethodName», "");


                void «fInterface.dbusStubAdapterClassNameInternal»::«broadcast.stubAdapterClassFireSelectiveMethodName»(«generateFireSelectiveSignatur(broadcast, fInterface)») {
                    std::shared_ptr<CommonAPI::DBus::DBusClientId> dbusClientId = std::dynamic_pointer_cast<CommonAPI::DBus::DBusClientId, CommonAPI::ClientId>(clientId);

                    if(dbusClientId)
                    {
                        CommonAPI::DBus::DBusStubSignalHelper<CommonAPI::DBus::DBusSerializableArguments<«broadcast.outArgs.map[getTypeName(fInterface.model)].join(', ')»>>
                            ::sendSignal(
                                dbusClientId->getDBusId(),
                                *this,
                                "«broadcast.elementName»",
                                "«broadcast.dbusSignature(deploymentAccessor)»"«IF broadcast.outArgs.size > 0»,«ENDIF»
                                «broadcast.outArgs.map[elementName].join(', ')»
                        );
                    }
                }

                void «fInterface.dbusStubAdapterClassNameInternal»::«broadcast.stubAdapterClassSendSelectiveMethodName»(«generateSendSelectiveSignatur(broadcast, fInterface, false)») {
                    std::shared_ptr<CommonAPI::ClientIdList> actualReceiverList;
                    actualReceiverList = receivers;

                    if(receivers == NULL)
                        actualReceiverList = «broadcast.stubAdapterClassSubscriberListPropertyName»;

                    for (auto clientIdIterator = actualReceiverList->cbegin();
                               clientIdIterator != actualReceiverList->cend();
                               clientIdIterator++) {
                        if(receivers == NULL || «broadcast.stubAdapterClassSubscriberListPropertyName»->find(*clientIdIterator) != «broadcast.stubAdapterClassSubscriberListPropertyName»->end()) {
                            «broadcast.stubAdapterClassFireSelectiveMethodName»(*clientIdIterator«IF(!broadcast.outArgs.empty)», «ENDIF»«broadcast.outArgs.map[elementName].join(', ')»);
                        }
                    }
                }

                void «fInterface.dbusStubAdapterClassNameInternal»::«broadcast.subscribeSelectiveMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId, bool& success) {
                    auto stub = stub_.lock();
                    bool ok = stub->«broadcast.subscriptionRequestedMethodName»(clientId);
                    if (ok) {
                        «broadcast.stubAdapterClassSubscriberListPropertyName»->insert(clientId);
                        stub->«broadcast.subscriptionChangedMethodName»(clientId, CommonAPI::SelectiveBroadcastSubscriptionEvent::SUBSCRIBED);
                        success = true;
                    } else {
                        success = false;
                    }
                }


                void «fInterface.dbusStubAdapterClassNameInternal»::«broadcast.unsubscribeSelectiveMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId) {
                    «broadcast.stubAdapterClassSubscriberListPropertyName»->erase(clientId);
                    auto stub = stub_.lock();
                    stub->«broadcast.subscriptionChangedMethodName»(clientId, CommonAPI::SelectiveBroadcastSubscriptionEvent::UNSUBSCRIBED);
                }

                std::shared_ptr<CommonAPI::ClientIdList> const «fInterface.dbusStubAdapterClassNameInternal»::«broadcast.stubAdapterClassSubscribersMethodName»() {
                    return «broadcast.stubAdapterClassSubscriberListPropertyName»;
                }

            «ELSE»
                void «fInterface.dbusStubAdapterClassNameInternal»::«broadcast.stubAdapterClassFireEventMethodName»(«broadcast.outArgs.map['const ' + getTypeName(fInterface.model) + '& ' + elementName].join(', ')») {
                    CommonAPI::DBus::DBusStubSignalHelper<CommonAPI::DBus::DBusSerializableArguments<«broadcast.outArgs.map[getTypeName(fInterface.model)].join(', ')»>>
                            ::sendSignal(
                                *this,
                                "«broadcast.elementName»",
                                "«broadcast.dbusSignature(deploymentAccessor)»"«IF broadcast.outArgs.size > 0»,«ENDIF»
                                «broadcast.outArgs.map[elementName].join(', ')»
                        );
                }
            «ENDIF»
        «ENDFOR»

        const «fInterface.dbusStubAdapterHelperClassName»::StubDispatcherTable& «fInterface.dbusStubAdapterClassNameInternal»::getStubDispatcherTable() {
            return stubDispatcherTable_;
        }

        «FOR managed : fInterface.managedInterfaces»
            
            bool «fInterface.dbusStubAdapterClassNameInternal»::«managed.stubRegisterManagedMethodImpl» {
                if («managed.stubManagedSetName».find(instance) == «managed.stubManagedSetName».end()) {
                    std::string commonApiAddress = "local:«managed.fullyQualifiedName»:" + instance;

                    std::string interfaceName;
                    std::string connectionName;
                    std::string objectPath;

                    CommonAPI::DBus::DBusAddressTranslator::getInstance().searchForDBusAddress(
                            commonApiAddress,
                            interfaceName,
                            connectionName,
                            objectPath);

                    if (objectPath.compare(0, dbusObjectPath_.length(), dbusObjectPath_) == 0) {
                        auto dbusStubAdapter = factory_->createDBusStubAdapter(stub, "«managed.fullyQualifiedName»",
                                instance, "«managed.fullyQualifiedName»", "local");

                        bool success = CommonAPI::DBus::DBusServicePublisher::getInstance()->registerManagedService(dbusStubAdapter);
                        if (success) {
                            bool isServiceExportSuccessful = dbusConnection_->getDBusObjectManager()->exportManagedDBusStubAdapter(dbusObjectPath_, dbusStubAdapter);
                            if (isServiceExportSuccessful) {
                                «managed.stubManagedSetName».insert(instance);
                                return true;
                            } else {
                                const bool isManagedDeregistrationSuccessful =
                                    CommonAPI::DBus::DBusServicePublisher::getInstance()->unregisterManagedService(
                                                    commonApiAddress);
                            }
                        }
                    }
                }
                return false;
            }

            bool «fInterface.dbusStubAdapterClassNameInternal»::«managed.stubDeregisterManagedName»(const std::string& instance) {
                std::string commonApiAddress = "local:«managed.fullyQualifiedName»:" + instance;
                if («managed.stubManagedSetName».find(instance) != «managed.stubManagedSetName».end()) {
                    std::shared_ptr<CommonAPI::DBus::DBusStubAdapter> dbusStubAdapter =
                                CommonAPI::DBus::DBusServicePublisher::getInstance()->getRegisteredService(commonApiAddress);
                    if (dbusStubAdapter != nullptr) {
                        dbusConnection_->getDBusObjectManager()->unexportManagedDBusStubAdapter(dbusObjectPath_, dbusStubAdapter);
                        CommonAPI::DBus::DBusServicePublisher::getInstance()->unregisterManagedService(commonApiAddress);
                        «managed.stubManagedSetName».erase(instance);
                        return true;
                    }
                }
                return false;
            }

            std::set<std::string>& «fInterface.dbusStubAdapterClassNameInternal»::«managed.stubManagedSetGetterName»() {
                return «managed.stubManagedSetName»;
            }
        «ENDFOR»

        «fInterface.dbusStubAdapterClassNameInternal»::«fInterface.dbusStubAdapterClassNameInternal»(
                const std::shared_ptr<CommonAPI::DBus::DBusFactory>& factory,
                const std::string& commonApiAddress,
                const std::string& dbusInterfaceName,
                const std::string& dbusBusName,
                const std::string& dbusObjectPath,
                const std::shared_ptr<CommonAPI::DBus::DBusProxyConnection>& dbusConnection,
                const std::shared_ptr<CommonAPI::StubBase>& stub):
                CommonAPI::DBus::DBusStubAdapter(
                        factory,
                        commonApiAddress,
                        dbusInterfaceName,
                        dbusBusName,
                        dbusObjectPath,
                        dbusConnection,
                        «IF !fInterface.managedInterfaces.nullOrEmpty»true«ELSE»false«ENDIF»),
                «fInterface.dbusStubAdapterHelperClassName»(
                    factory,
                    commonApiAddress,
                    dbusInterfaceName,
                    dbusBusName,
                    dbusObjectPath,
                    dbusConnection,
                    std::dynamic_pointer_cast<«fInterface.stubClassName»>(stub),
                    «IF !fInterface.managedInterfaces.nullOrEmpty»true«ELSE»false«ENDIF»),
                «IF fInterface.base != null»
                «fInterface.base.dbusStubAdapterClassNameInternal»(
                    factory,
                    commonApiAddress,
                    dbusInterfaceName,
                    dbusBusName,
                    dbusObjectPath,
                    dbusConnection,
                    stub),
                «ENDIF»
                stubDispatcherTable_({
                    «FOR attribute : fInterface.attributes SEPARATOR ','»
                        «FTypeGenerator::generateComments(attribute, false)»
                        { { "«attribute.dbusGetMethodName»", "" }, &«fInterface.absoluteNamespace»::«attribute.dbusGetStubDispatcherVariable» }
                        «IF !attribute.isReadonly»
                            , { { "«attribute.dbusSetMethodName»", "«attribute.dbusSignature(deploymentAccessor)»" }, &«fInterface.absoluteNamespace»::«attribute.dbusSetStubDispatcherVariable» }
                        «ENDIF»
                    «ENDFOR»
                    «IF !fInterface.attributes.empty && !fInterface.methods.empty»,«ENDIF»
                    «FOR method : fInterface.methods SEPARATOR ','»
                        «FTypeGenerator::generateComments(method, false)»
                        «IF methodnumberMap.get(method)==0»
                        { { "«method.elementName»", "«method.dbusInSignature(deploymentAccessor)»" }, &«fInterface.absoluteNamespace»::«method.dbusStubDispatcherVariable» }
                        «ELSE»
                        { { "«method.elementName»", "«method.dbusInSignature(deploymentAccessor)»" }, &«fInterface.absoluteNamespace»::«method.dbusStubDispatcherVariable»«methodnumberMap.get(method)» }
                        «ENDIF»
                    «ENDFOR»
                    «IF fInterface.hasSelectiveBroadcasts»,«ENDIF»
                    «FOR broadcast : fInterface.broadcasts.filter[!selective.nullOrEmpty] SEPARATOR ','»
                        { { "«broadcast.subscribeSelectiveMethodName»", "" }, &«fInterface.absoluteNamespace»::«broadcast.dbusStubDispatcherVariableSubscribe» },
                        { { "«broadcast.unsubscribeSelectiveMethodName»", "" }, &«fInterface.absoluteNamespace»::«broadcast.dbusStubDispatcherVariableUnsubscribe» }
                    «ENDFOR»
                    }) {
            «FOR broadcast : fInterface.broadcasts»
                «IF !broadcast.selective.nullOrEmpty»
                    «broadcast.getStubAdapterClassSubscriberListPropertyName» = std::make_shared<CommonAPI::ClientIdList>();
                «ENDIF»
            «ENDFOR»

            «IF fInterface.base != null»
                auto parentDispatcherTable = «fInterface.base.dbusStubAdapterClassNameInternal»::getStubDispatcherTable();
                stubDispatcherTable_.insert(parentDispatcherTable.begin(), parentDispatcherTable.end());

                auto interfaceVersionGetter = stubDispatcherTable_.find({ "getInterfaceVersion", "" });
                if(interfaceVersionGetter != stubDispatcherTable_.end()) {
                    interfaceVersionGetter->second = &«fInterface.absoluteNamespace»::get«fInterface.elementName»InterfaceVersionStubDispatcher;
                } else {
                    stubDispatcherTable_.insert({ { "getInterfaceVersion", "" }, &«fInterface.absoluteNamespace»::get«fInterface.elementName»InterfaceVersionStubDispatcher });
                }
            «ELSE»
               stubDispatcherTable_.insert({ { "getInterfaceVersion", "" }, &«fInterface.absoluteNamespace»::get«fInterface.elementName»InterfaceVersionStubDispatcher });
            «ENDIF»
        }

        «fInterface.model.generateNamespaceEndDeclaration»
    '''

    def private getAbsoluteNamespace(FModelElement fModelElement) {
        fModelElement.model.name.replace('.', '::')
    }

    def private dbusStubAdapterHeaderFile(FInterface fInterface) {
        fInterface.elementName + "DBusStubAdapter.h"
    }

    def private dbusStubAdapterHeaderPath(FInterface fInterface) {
        fInterface.model.directoryPath + '/' + fInterface.dbusStubAdapterHeaderFile
    }

    def private dbusStubAdapterSourceFile(FInterface fInterface) {
        fInterface.elementName + "DBusStubAdapter.cpp"
    }

    def private dbusStubAdapterSourcePath(FInterface fInterface) {
        fInterface.model.directoryPath + '/' + fInterface.dbusStubAdapterSourceFile
    }

    def private dbusStubAdapterClassName(FInterface fInterface) {
        fInterface.elementName + 'DBusStubAdapter'
    }

    def private dbusStubAdapterClassNameInternal(FInterface fInterface) {
        fInterface.dbusStubAdapterClassName + 'Internal'
    }
    
    def private dbusStubAdapterHelperClassName(FInterface fInterface) {
        fInterface.elementName + 'DBusStubAdapterHelper'
    }

    def private getAllInTypes(FMethod fMethod) {
        fMethod.inArgs.map[getTypeName(fMethod.model)].join(', ')
    }

    def private getAllOutTypes(FMethod fMethod) {
        var types = fMethod.outArgs.map[getTypeName(fMethod.model)].join(', ')

        if (fMethod.hasError) {
            if (!fMethod.outArgs.empty)
                types = ', ' + types
            types = fMethod.getErrorNameReference(fMethod.eContainer) + types
        }

        return types
    }

    def private dbusStubDispatcherVariable(FMethod fMethod) {
        fMethod.elementName.toFirstLower + 'StubDispatcher'
    }

    def private dbusGetStubDispatcherVariable(FAttribute fAttribute) {
        fAttribute.dbusGetMethodName + 'StubDispatcher'
    }

    def private dbusSetStubDispatcherVariable(FAttribute fAttribute) {
        fAttribute.dbusSetMethodName + 'StubDispatcher'
    }

    def private dbusStubDispatcherVariable(FBroadcast fBroadcast) {
        fBroadcast.elementName.toFirstLower + if(!fBroadcast.selective.isNullOrEmpty){'Selective'} + 'StubDispatcher'
    }

    def private dbusStubDispatcherVariableSubscribe(FBroadcast fBroadcast) {
        "subscribe" + fBroadcast.dbusStubDispatcherVariable.toFirstUpper
    }

    def private dbusStubDispatcherVariableUnsubscribe(FBroadcast fBroadcast) {
        "unsubscribe" + fBroadcast.dbusStubDispatcherVariable.toFirstUpper
    }
}
