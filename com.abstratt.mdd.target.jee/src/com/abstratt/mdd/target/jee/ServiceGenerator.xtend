package com.abstratt.mdd.target.jee

import com.abstratt.mdd.core.IRepository
import org.eclipse.uml2.uml.Class
import org.eclipse.uml2.uml.Operation
import org.eclipse.uml2.uml.ParameterDirectionKind
import org.eclipse.uml2.uml.Activity

import static extension com.abstratt.kirra.mdd.core.KirraHelper.*
import static extension com.abstratt.mdd.core.util.ActivityUtils.*
import static extension com.abstratt.mdd.core.util.MDDExtensionUtils.*
import static extension com.abstratt.mdd.core.util.StateMachineUtils.*


class ServiceGenerator extends EntityGenerator {
    
    new(IRepository repository) {
        super(repository)
    }
    
    def generateService(Class entity) {
        val serviceOperations = entity.allOperations.filter[static]
        '''
        package «entity.packagePrefix»;
        
        import java.util.*;
        import java.util.stream.*;
        import javax.persistence.*;
        import javax.inject.*;
        import javax.ejb.*;
        import javax.enterprise.event.*;
        
        «entity.generateImports»
        
        public class «entity.name»Service {
            «generateMany(findTriggerableSignals(serviceOperations), [generateSignal])»
            
            «serviceOperations.generateMany[generateServiceOperation]»
        }
        '''
    }
    
    def generateServiceOperation(Operation serviceOperation) {
        serviceOperation.generateJavaMethod(serviceOperation.visibility)
    }
}